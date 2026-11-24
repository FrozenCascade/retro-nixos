# The password check behind the Quickshell lock screen (components/lock/LockScreen.qml asks PAM for
# the service named below). An empty definition gives the standard login rules: your user password.
{
  security.pam.services.quickshell-lock = { };
}
