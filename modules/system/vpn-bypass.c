/* vpn-bypass: run a command with the extra group `vpnbypass` (see vpn-bypass.nix for the firewall side).
 * Installed setuid root by NixOS only so it may add that one group. It then gives the root rights back
 * and starts the command as the same user, with the same main group and nothing else changed.
 * Keeping the main group is what lets the desktop portal (screen sharing, file pickers) see the app. */
#define _GNU_SOURCE
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define BYPASS_GROUP "vpnbypass"

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: vpn-bypass <command> [arguments]\n");
        return 1;
    }

    struct group *bypass = getgrnam(BYPASS_GROUP);
    if (!bypass) {
        fprintf(stderr, "vpn-bypass: no group '%s'\n", BYPASS_GROUP);
        return 1;
    }

    uid_t uid = getuid();
    gid_t gid = getgid();

    /* the caller's groups, plus the bypass group */
    int n = getgroups(0, NULL);
    gid_t *groups = malloc((n + 1) * sizeof(gid_t));
    if (!groups || (n = getgroups(n, groups)) < 0) {
        perror("vpn-bypass: getgroups");
        return 1;
    }
    groups[n++] = bypass->gr_gid;

    /* order matters: groups first (needs root), then drop root for good */
    if (setgroups(n, groups) != 0 || setresgid(gid, gid, gid) != 0 || setresuid(uid, uid, uid) != 0) {
        perror("vpn-bypass");
        return 1;
    }

    execvp(argv[1], argv + 1);
    perror(argv[1]);
    return 127;
}
