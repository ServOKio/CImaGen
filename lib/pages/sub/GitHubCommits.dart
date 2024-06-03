import 'package:cimagen/main.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../utils/GitHub.dart';

class GitHubCommits extends StatefulWidget {
  GitHubCommits({Key? key}) : super(key: key);

  @override
  _GitHubCommitsState createState() => _GitHubCommitsState();
}

class _CommitData {
  final Commit commit;
  String? buildSha;

  _CommitData(this.commit, this.buildSha);
}

class _GitHubCommitsState extends State<GitHubCommits> {
  bool loaded = false;

  late List<_CommitData> _commits;
  bool _initialized = false;

  void _getCommits() async {
    final buildCommits = await githubAPI!.getCommits(params: { 'sha': 'builds', 'path': 'Injector.dex', 'per_page': '50' });
    final commits = await githubAPI?.getCommits(params: { 'per_page': '50' });
    _commits = commits!.map((c) => _CommitData(c, buildCommits.firstWhereOrNull((bc) => bc.commit.message.substring(6) == c.sha)?.sha)).toList();
    setState(() => _initialized = true);

    // widget.selectCommit(buildCommits.first.sha);
  }

  @override
  void initState() {
    super.initState();
    // GitHub!.addListener(_getCommits);
    _getCommits();
  }

  @override
  void dispose() {
    // githubAPI!.removeListener(_getCommits);
    super.dispose();
  }

  Widget _buildCommit(BuildContext context, int i) {
    final commit = _commits[i].commit;
    final hasBuild = _commits[i].buildSha != null;
    final linkStyle = TextStyle(color: Theme.of(context).colorScheme.secondary);
    return Padding(padding: i != 0 ? const EdgeInsets.all(12) : const EdgeInsets.only(left: 12, right: 12, bottom: 12), child: Row(children: [
      Expanded(flex: 1, child: Row(children: [
        InkWell(
          child: Text(commit.sha.substring(0, 7), style: hasBuild ? linkStyle : const TextStyle(color: Colors.grey)),
          onTap: (){
            // sosi
          }
        ),
        const SizedBox.shrink(),
      ])),
      Expanded(flex: 4, child: Text('${commit.commit.message.split('\n')[0]} - ${commit.author}', style: const TextStyle(fontSize: 16))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('Commits'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: [
            ]
        ),
        body: SafeArea(
          child: !_initialized || _commits.isEmpty ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(
            child: CircularProgressIndicator(),
          )) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.all(15), child: Text('Commits', style: Theme.of(context).textTheme.titleMedium)),
              Expanded(child: ListView.separated(
                itemBuilder: _buildCommit,
                separatorBuilder: (context, i) => const Divider(),
                itemCount: _commits.length,
              ))
            ],
          ),
        )
    );
  }
}