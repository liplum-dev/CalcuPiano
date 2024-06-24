import 'package:audioplayers/audioplayers.dart';
import 'package:calcupiano/design/multiplatform.dart';

import 'package:calcupiano/foundation.dart';
import 'package:calcupiano/r.dart';
import 'package:calcupiano/stage_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:rettulf/rettulf.dart';

class SoundpackComposer extends StatefulWidget {
  final LocalSoundpack soundpack;

  const SoundpackComposer(this.soundpack, {super.key});

  @override
  State<SoundpackComposer> createState() => _SoundpackComposerState();
}

class _SoundpackComposerState extends State<SoundpackComposer> {
  LocalSoundpack get edited => widget.soundpack;
  final Map<Note, SoundFileResolveProtocol> $view = {};
  final queue = _OpQueue();

  @override
  void initState() {
    super.initState();
    for (final p in edited.note2SoundFile.entries) {
      final note = p.key;
      $view[note] = LocalSoundFileLoc(edited, note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await StageManager.closeSoundFileExplorerKey(ctx: context);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: edited.displayName.text(overflow: TextOverflow.fade),
          centerTitle: context.isCupertino,
          actions: [
            IconButton(
                icon: const Icon(Icons.playlist_play_outlined), onPressed: () async => await playSoundInNoteOrder()),
            IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () async => await StageManager.showSoundFileExplorer(ctx: context)),
            IconButton(icon: const Icon(Icons.save_rounded), onPressed: () async => await onSave(context)),
          ],
        ),
        body: buildBody(context),
      ),
    );
  }

  Future<void> onSave(BuildContext ctx) async {
    // TODO: on Windows: OS Error: The process cannot access the file because it is being used by another process.
    final changed = await queue.performAll(edited);
    if (changed) {
      DB.setSoundpackSnapshotById(edited);
      // TODO: I don't know why it doesn't work on Android. Users have to restart Calcupiano.
      await AudioCache.instance.clearAll();
    }
    await StageManager.closeSoundFileExplorerKey(ctx: ctx);
    if (!mounted) return;
    ctx.navigator.pop();
  }

  Future<void> playSoundInNoteOrder() async {
    for (final note in Note.all) {
      final file = $view[note]?.resolve();
      if (file != null) {
        Player.playSound(file);
        // TODO: Customize interval
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Widget buildBody(BuildContext ctx) {
    return ListView.separated(
      physics: const RangeMaintainingScrollPhysics(),
      itemCount: Note.all.length,
      itemBuilder: (ctx, index) {
        final note = Note.all[index];
        return _SoundFileRow(
          note: note,
          edited: edited,
          getFile: () => $view[note],
          setFile: (f) {
            if (f == null) {
              $view.remove(note);
              queue.add(_RemoveOp(note));
            } else {
              $view[note] = f;
              if (f is LocalSoundFileLoc && f.soundpack.idEquals(edited)) {
                // If the source is target, swap these two files to avoid to copy self.
                queue.add(_SwapOp(f, LocalSoundFileLoc(edited, note)));
              } else {
                queue.add(_ReplaceOp(f.resolve(), note));
              }
            }
          },
        );
      },
      separatorBuilder: (BuildContext context, int index) {
        return const Divider(thickness: 1);
      },
    );
  }
}

class _SoundFileRow extends StatefulWidget {
  final Note note;
  final ValueGetter<SoundFileResolveProtocol?> getFile;
  final ValueSetter<SoundFileResolveProtocol?> setFile;
  final LocalSoundpack edited;

  const _SoundFileRow({
    required this.edited,
    required this.note,
    required this.getFile,
    required this.setFile,
  });

  @override
  State<_SoundFileRow> createState() => _SoundFileRowState();
}

class _SoundFileRowState extends State<_SoundFileRow> {
  Note get note => widget.note;

  SoundFileResolveProtocol? get file => widget.getFile();

  set file(SoundFileResolveProtocol? newFile) {
    widget.setFile(newFile);
    setState(() {});
  }

  SoundpackProtocol get edited => widget.edited;

  @override
  Widget build(BuildContext context) {
    final sound = file;
    return IntrinsicHeight(
      child: [
        [
          buildTitle(sound),
          buildBottomBar(sound),
        ]
            .column()
            .inCard(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            )
            .expanded(),
        buildUploadArea(sound).expanded(),
      ].row(caa: CrossAxisAlignment.stretch),
    );
  }

  Widget buildTitle(SoundFileResolveProtocol? sound) {
    return Text.rich([
      TextSpan(text: note.numberedText),
      WidgetSpan(child: sound != null ? const Icon(Icons.music_note) : const Icon(Icons.music_off)),
    ].span(style: context.textTheme.headlineLarge))
        .padAll(5)
        .center();
  }

  Widget buildBottomBar(SoundFileResolveProtocol? sound) {
    return ButtonBar(
      alignment: MainAxisAlignment.center,
      children: [
        if (sound != null) buildPlaySoundBtn(sound),
      ],
    ).container(
        decoration: BoxDecoration(
      color: context.colorScheme.surface,
    ));
  }

  Widget buildAudioFileArea(SoundFileResolveProtocol? loc) {
    const icon = Icon(Icons.upload_file_outlined, size: 36);
    Widget audioFileArea;
    if (loc != null) {
      final String? subtitle;
      final file = loc.resolve();
      if (file is LocalSoundFile) {
        subtitle = file.localPath;
      } else if (loc is SoundFileLoc) {
        // TODO: I18n
        subtitle = "${loc.note.id} from ${loc.soundpack.displayName}";
      } else {
        subtitle = null;
      }
      audioFileArea = [
        icon,
        if (subtitle != null) basenameOfPath(subtitle).text(),
      ].column(maa: MainAxisAlignment.center);
    } else {
      audioFileArea = icon;
    }
    return InkWell(
      onTap: () async {
        final audio = await Packager.tryPickAudioFile();
        if (audio != null) {
          file = LocalSoundFile(localPath: audio);
        }
      },
      child: audioFileArea,
    );
  }

  Widget buildDropIndicator(SoundFileLoc loc) {
    const icon = Icon(Icons.move_to_inbox_outlined, size: 36);
    // TODO: I18n
    final String subtitle;
    if (loc is LocalSoundFileLoc && loc.soundpack.idEquals(edited)) {
      subtitle = "Swap ${loc.note.id} with ${note.id}";
    } else {
      subtitle = "${loc.note.id} from ${loc.soundpack.displayName}";
    }
    Widget dropIndicator = [
      icon,
      basenameOfPath(subtitle).text(),
    ].column(maa: MainAxisAlignment.center);
    return dropIndicator;
  }

  Widget buildUploadArea(SoundFileResolveProtocol? loc) {
    Widget audioFileArea = buildAudioFileArea(loc);
    final dropArea = DragTarget<SoundFileLoc>(
      builder: (ctx, candidateData, rejectedData) {
        final Widget res;
        final first = candidateData.firstOrNull;
        if (first != null) {
          res = buildDropIndicator(first);
        } else {
          res = audioFileArea;
        }
        return res;
      },
      onAcceptWithDetails: (details) {
        file = details.data;
      },
      onWillAcceptWithDetails: (details) {
        final loc = details.data;
        if (loc is LocalSoundFileLoc && loc.soundpack.idEquals(edited)) {
          return loc.note != note;
        } else {
          return true;
        }
      },
    );
    final res = dropArea.inCard(
      elevation: 0,
      clip: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
    return res;
  }

  Widget buildPlaySoundBtn(SoundFileResolveProtocol loc) {
    return IconButton(
      onPressed: () async {
        Player.playSound(loc.resolve());
      },
      icon: const Icon(Icons.play_arrow),
    );
  }

  /// Search a SoundFile in another soundpack.
  Future<void> searchInAnother() async {}
}

class _OpQueue {
  final _queue = <_Op>[];

  void add(_Op op) {
    _queue.add(op);
  }

  Future<bool> performAll(LocalSoundpack soundpack) async {
    var changed = false;
    for (final op in _queue) {
      await op.perform(soundpack);
      changed = true;
    }
    _queue.clear();
    return changed;
  }
}

/// A composition operation
abstract class _Op {
  Future<void> perform(LocalSoundpack soundpack);
}

/// Replace old SoundFile with new SoundFile from different Soundpack
class _ReplaceOp implements _Op {
  final SoundFileProtocol newFile;
  final Note target;

  const _ReplaceOp(this.newFile, this.target);

  @override
  Future<void> perform(LocalSoundpack soundpack) async {
    final copied = await newFile.copyTo(joinPath(R.soundpacksRootDir, soundpack.uuid), target.id, extSuggestion: null);
    soundpack.note2SoundFile[target] = LocalSoundFile(localPath: copied);
  }
}

class _RemoveOp implements _Op {
  final Note removed;

  const _RemoveOp(this.removed);

  @override
  Future<void> perform(LocalSoundpack soundpack) async {
    final file = soundpack.resolve(removed);
    await file.toFile().delete();
    soundpack.note2SoundFile.remove(removed);
  }
}

/// Swap two SoundFiles in the same Soundpack
class _SwapOp implements _Op {
  final LocalSoundFileLoc a;
  final LocalSoundFileLoc b;

  const _SwapOp(this.a, this.b);

  @override
  Future<void> perform(LocalSoundpack soundpack) async {
    final fileA = a.resolve();
    final fileB = b.resolve();
    await Packager.swapFiles(fileA.localPath, fileB.localPath);
    soundpack.note2SoundFile[a.note] = fileB;
    soundpack.note2SoundFile[b.note] = fileA;
  }
}
