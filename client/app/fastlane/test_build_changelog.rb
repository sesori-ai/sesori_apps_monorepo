# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "build_changelog"

class BuildChangelogHistoryTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def setup
    # Keep disposable Git fixtures inside the caller's checkout, not a worktree.
    @repo = Dir.mktmpdir(".release-notes-test-", ROOT)
    git(args: ["init", "--initial-branch=main"])
    # Detached Git maintenance must not mutate objects during fixture teardown.
    git(args: ["config", "maintenance.auto", "false"])
    git(args: ["config", "gc.auto", "0"])
    git(args: ["config", "user.name", "Release Notes Test"])
    git(args: ["config", "user.email", "release-notes@example.invalid"])
    git(args: ["config", "commit.gpgsign", "false"])
    git(args: ["config", "tag.gpgsign", "false"])
    commit(message: "Initial commit")
  end

  def teardown
    FileUtils.remove_entry(@repo)
  end

  def test_all_commits_since_annotated_internal_release_not_attempt_marker
    git(args: ["tag", "-a", "v1.2.3-internal.42", "-m", "Successful release"])
    commit(message: "First fix\n\nLong commit body is not a separate entry.")
    git(args: ["tag", "internal-release-attempt"])
    commit(message: "Second fix")
    git(args: ["tag", "unrelated-checkpoint"])
    sha = commit(message: "Docs after product changes")

    assert_equal "commit: #{sha[0, 7]}\n- Docs after product changes\n- Second fix\n- First fix", notes(target: sha)
  end

  def test_stable_tag_is_a_release_baseline
    git(args: ["tag", "v1.2.3"])
    sha = commit(message: "New feature")

    assert_equal "commit: #{sha[0, 7]}\n- New feature", notes(target: "HEAD")
  end

  def test_nearest_internal_release_replaces_older_stable_baseline
    git(args: ["tag", "v1.2.3"])
    commit(message: "Already released internally")
    git(args: ["tag", "-a", "v1.2.4-internal.43", "-m", "Next release"])
    sha = commit(message: "Only new change")

    assert_equal "commit: #{sha[0, 7]}\n- Only new change", notes(target: sha)
  end

  def test_first_release_includes_all_history
    commit(message: "Second commit")
    git(args: ["tag", "internal-release-attempt"])
    sha = commit(message: "Third commit")

    assert_equal "commit: #{sha[0, 7]}\n- Third commit\n- Second commit\n- Initial commit", notes(target: sha)
  end

  def test_target_is_immutable_even_with_newer_head_and_release_tag
    git(args: ["tag", "v1.2.3"])
    sha = commit(message: "Build this commit")
    commit(message: "Later commit")
    git(args: ["tag", "v1.2.4-internal.44"])

    assert_equal "commit: #{sha[0, 7]}\n- Build this commit", notes(target: sha)
  end

  def test_release_on_merged_side_branch_does_not_hide_newly_merged_commits
    git(args: ["tag", "v1.2.3"])
    git(args: ["checkout", "-b", "feature"])
    commit(message: "Feature from branch")
    git(args: ["tag", "v1.2.4-internal.44"])
    git(args: ["checkout", "main"])
    commit(message: "Main change")
    git(args: ["merge", "--no-ff", "feature", "-m", "Merge feature"])

    text = notes(target: "HEAD")
    assert_includes text, "- Feature from branch"
    assert_includes text, "- Main change"
    assert_includes text, "- Merge feature"
    refute_includes text, "- Initial commit"
  end

  def test_rebuilding_tagged_commit_shows_only_build_sha
    git(args: ["tag", "v1.2.3-internal.42"])
    sha = git(args: ["rev-parse", "HEAD"])

    assert_equal "commit: #{sha[0, 7]}", notes(target: sha)
  end

  def test_git_errors_are_not_replaced_with_misleading_tip_notes
    error = assert_raises(RuntimeError) { notes(target: "missing-ref") }
    assert_includes error.message, "rev-parse --verify missing-ref^{commit} failed:"
  end

  def test_shallow_history_is_rejected
    sha = git(args: ["rev-parse", "HEAD"])
    File.write(File.join(@repo, ".git", "shallow"), "#{sha}\n")

    error = assert_raises(RuntimeError) { notes(target: "HEAD") }
    assert_includes error.message, "full Git history"
  end

  private

  def git(args:)
    output, error, status = Open3.capture3("git", "-C", @repo, *args)
    raise "Git fixture failed: #{error}" unless status.success?

    output.strip
  end

  def commit(message:)
    git(args: ["commit", "--allow-empty", "-m", message])
    git(args: ["rev-parse", "HEAD"])
  end

  def notes(target:)
    SesoriBuildChangelog.generate(
      repo_path: @repo, target: target, max_length: SesoriBuildChangelog::TESTFLIGHT_MAX_LENGTH
    )
  end
end

class BuildChangelogLengthTest < Minitest::Test
  HEADER = "commit: 1234567"

  def test_all_entries_fit_without_footer_including_exact_limit
    text = render(subjects: ["Newest", "Older"], max_length: 100)

    assert_equal "#{HEADER}\n- Newest\n- Older", text
    assert_equal text, render(subjects: ["Newest", "Older"], max_length: text.length)
  end

  def test_do_not_reserve_footer_when_all_short_entries_fit
    subjects = ["Newest", "x"]
    expected = "#{HEADER}\n- Newest\n- x"

    assert_equal expected, render(subjects: subjects, max_length: expected.length)
  end

  def test_footer_is_last_and_count_includes_entries_displaced_by_footer
    expected = "#{HEADER}\n- Newest\n+ 2 others"
    text = render(subjects: ["Newest", "Middle", "Oldest"], max_length: expected.length)

    assert_equal expected, text
  end

  def test_single_oversized_entry_is_omitted_and_counted
    assert_equal "#{HEADER}\n+ 1 others", render(subjects: ["x" * 5000], max_length: 4000)
  end

  def test_oversized_newest_entry_counts_every_omitted_commit
    assert_equal "#{HEADER}\n+ 3 others", render(subjects: ["x" * 500, "Older", "Oldest"], max_length: 400)
  end

  def test_footer_accounts_for_count_digit_boundary
    subjects = Array.new(11) { |index| "Change #{index}" }
    expected = "#{HEADER}\n- Change 0\n+ 10 others"

    assert_equal expected, render(subjects: subjects, max_length: expected.length)
    assert_equal "#{HEADER}\n+ 11 others", render(subjects: subjects, max_length: expected.length - 1)
  end

  def test_unicode_is_counted_as_characters_not_bytes_and_never_split
    subjects = ["🌿 Café 中文", "⚙️ Résumé", "Oldest change" * 10]
    expected = "#{HEADER}\n- 🌿 Café 中文\n- ⚙️ Résumé\n+ 1 others"
    text = render(subjects: subjects, max_length: expected.length)

    assert_equal expected, text
    assert text.valid_encoding?
    assert_operator text.bytesize, :>, text.length
  end

  def test_both_store_limits_keep_maximal_complete_prefix_and_exact_count
    subjects = Array.new(120) { |index| "🌿 Change #{index}: improve release batching" }
    [SesoriBuildChangelog::PLAY_MAX_LENGTH, SesoriBuildChangelog::TESTFLIGHT_MAX_LENGTH].each do |limit|
      text = render(subjects: subjects, max_length: limit)
      shown = text.lines.count { |line| line.start_with?("- ") }
      omitted = subjects.length - shown

      assert_operator text.length, :<=, limit
      assert_operator shown, :>, 0
      assert_equal "+ #{omitted} others", text.lines.last
      assert_equal subjects.first(shown).map { |subject| "- #{subject}" }, text.lines(chomp: true)[1, shown]
      with_next = ([HEADER] + subjects.first(shown + 1).map { |subject| "- #{subject}" } +
        ["+ #{omitted - 1} others"]).join("\n")
      assert_operator with_next.length, :>, limit
    end
  end

  private

  def render(subjects:, max_length:)
    SesoriBuildChangelog.render(subjects: subjects, sha: "1234567890abcdef", max_length: max_length)
  end
end
