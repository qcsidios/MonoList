import Foundation

@main
struct UpdateInstallerSmoke {
    static func main() throws {
        if CommandLine.arguments.count == 3,
           CommandLine.arguments[1] == "--emit-script" {
            try UpdateInstaller.updaterScript.write(
                toFile: CommandLine.arguments[2],
                atomically: true,
                encoding: .utf8
            )
            return
        }
        let script = UpdateInstaller.updaterScript
        precondition(script.contains("hdiutil verify"))
        precondition(script.contains("BACKUP_PATH"))
        precondition(script.contains("ditto"))
        precondition(script.contains("restore_old_app"))
        precondition(script.contains("com.qingcheng.monolist.mac"))
        precondition(script.contains("pgrep -x MenuBarService"))
        precondition(script.contains("codesign --verify"))
        precondition(script.contains("xattr -dr com.apple.quarantine"))
        precondition(!script.contains("github.com"))
        print("Update installer smoke passed.")
    }
}
