import "package:sesori_bridge/src/api/drive_roots_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";

void main() {
  test("macOS lists writable Finder-visible volumes from mount in path order", () async {
    final processRunner = RecordingProcessRunner(
      stdout: """
/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
/dev/disk3s3 on /Volumes/Recovery (apfs, local, journaled, nobrowse)
/dev/disk5s1 on /Volumes/Work SSD (apfs, local, nodev, nosuid, journaled, noowners)
/dev/disk6s2 on /Volumes/Some App (hfs, local, nodev, nosuid, read-only, noowners, quarantine, mounted by dev)
//dev@nas/share on /Volumes/share (smbfs, nodev, nosuid, mounted by dev)
/dev/disk4s1 on /Volumes/Archive (apfs, local, nodev, nosuid, journaled, noowners)
""",
    );
    final api = DriveRootsApi.forPlatform(
      platform: PlatformOs.macos,
      processRunner: processRunner,
    );

    expect(await api.listCandidates(), ["/Volumes/Archive", "/Volumes/Work SSD", "/Volumes/share"]);
    expect(processRunner.executable, "/sbin/mount");
  });

  test("Linux lists writable top-level mounts, leaving out ISOs and WSL plumbing", () async {
    final processRunner = RecordingProcessRunner(
      stdout: r"""
/dev/sda2 / ext4 rw,relatime 0 0
/dev/sdb1 /media/dev/Data\040Disk ext4 rw,nosuid,nodev 0 0
/dev/sr0 /media/dev/Ubuntu iso9660 ro,nosuid,nodev 0 0
/dev/sdc1 /run/media/dev/USB vfat rw,nosuid,nodev 0 0
none /mnt/wslg tmpfs rw,relatime 0 0
none /mnt/wslg/doc overlay rw,relatime 0 0
C:\134 /mnt/c 9p rw,noatime 0 0
""",
    );
    final api = DriveRootsApi.forPlatform(platform: PlatformOs.linux, processRunner: processRunner);

    expect(await api.listCandidates(), ["/media/dev/Data Disk", "/mnt/c", "/run/media/dev/USB"]);
    expect(processRunner.arguments, ["/proc/mounts"]);
  });
}
