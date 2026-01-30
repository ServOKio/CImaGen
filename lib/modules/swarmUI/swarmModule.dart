class SwarmClientInfo{
  String? sessionID;
  final String userID;
  final bool outputAppendUser;
  final String version;
  final String serverID;
  final int countRunning;
  final List<String> permissions;

  SwarmClientInfo({
    this.sessionID,
    required this.userID,
    required this.outputAppendUser,
    required this.version,
    required this.serverID,
    required this.countRunning,
    required this.permissions
  });
}