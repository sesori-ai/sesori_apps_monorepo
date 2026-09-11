# frozen_string_literal: true

require "open3"

# Shared TEST release notes. Production store copy still comes from private metadata.
module SesoriBuildChangelog
  TESTFLIGHT_MAX_LENGTH = 4000
  # Play documents 500 Unicode characters, but this pipeline has seen rejections
  # below that cap. Preserve its existing conservative 400-character budget.
  PLAY_MAX_LENGTH = 400

  def self.generate(repo_path:, target:, max_length:)
    if git(repo_path: repo_path, args: ["rev-parse", "--is-shallow-repository"]).strip == "true"
      raise "Release notes require full Git history. Fetch with --unshallow and --tags."
    end

    sha = git(repo_path: repo_path, args: ["rev-parse", "--verify", "#{target}^{commit}"]).strip
    # v* tags mark completed releases; internal-release-attempt must never reset
    # this range after a failed build. Follow the target's own release history,
    # not a newer tag elsewhere or a release on a merged side branch.
    baseline = git(
      repo_path: repo_path,
      args: ["describe", "--tags", "--first-parent", "--match", "v[0-9]*", "--abbrev=0", "--always", sha]
    ).strip
    # --always returns a SHA when no release exists: include all history then.
    range = baseline.start_with?("v") ? "#{baseline}..#{sha}" : sha
    subjects = git(
      repo_path: repo_path,
      args: ["log", "--topo-order", "--format=%s", range, "--"]
    ).lines(chomp: true)
    render(subjects: subjects, sha: sha, max_length: max_length)
  end

  def self.render(subjects:, sha:, max_length:)
    header = "commit: #{sha[0, 7]}"
    entries = subjects.map { |subject| "- #{subject}" }
    full_text = ([header] + entries).join("\n")
    return full_text if full_text.length <= max_length

    # Keep complete newest entries only. Reserve the exact footer (including
    # its newline and count digits) before accepting each entry. Even one huge
    # subject is omitted and counted rather than being silently cut mid-message.
    lines = [header]
    length = header.length
    entries.each_with_index do |entry, index|
      remaining = entries.length - index - 1
      footer_length = remaining.positive? ? "\n+ #{remaining} others".length : 0
      break if length + 1 + entry.length + footer_length > max_length

      lines << entry
      length += 1 + entry.length
    end
    omitted = entries.length - (lines.length - 1)
    lines << "+ #{omitted} others" if omitted.positive?
    lines.join("\n")
  end

  def self.git(repo_path:, args:)
    output, error, status = Open3.capture3("git", "-C", repo_path, *args)
    raise "git #{args.join(' ')} failed: #{error.strip}" unless status.success?

    output
  end
  private_class_method :git
end
