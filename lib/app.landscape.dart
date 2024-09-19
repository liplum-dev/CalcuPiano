part of 'app.dart';

class HomeTabletLandscape extends StatefulWidget {
  const HomeTabletLandscape({super.key});

  @override
  State<StatefulWidget> createState() => _HomeTabletLandscapeState();
}

class _HomeTabletLandscapeState extends State<HomeTabletLandscape> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;

  @override
  void didUpdateWidget(covariant HomeTabletLandscape oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isOpen = _scaffoldKey.currentState?.isDrawerOpen;
    if (isOpen != null && isOpen != _isDrawerOpen) {
      setState(() {
        _isDrawerOpen = isOpen;
      });
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeDrawer(BuildContext ctx) {
    ctx.navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: CalcuPianoDrawer(
        onCloseDrawer: () {
          _closeDrawer(context);
        },
      ),
      onDrawerChanged: (isOpened) {
        if (isOpened != _isDrawerOpen) {
          setState(() {
            _isDrawerOpen = isOpened;
          });
        }
      },
      body: buildMain(context),
    );
  }

  Widget buildMain(BuildContext ctx) {
    return Scaffold(
      body: [
        NavigationDrawer(children: [
          NavigationDrawerDestination(
            icon: const Icon(Icons.menu_rounded),
            label: "Menu".text(),
          )
        ]).expanded(flex: 1),
        const SheetScreen().expanded(flex: 2),
        // Why doesn't the constraint apply on this?
        const PianoKeyboard().expanded(flex: 3),
      ]
          .row(
            mas: MainAxisSize.min,
            maa: MainAxisAlignment.center,
          )
          .safeArea(),
    );
  }
}

class HomeDesktopLandscape extends StatefulWidget {
  const HomeDesktopLandscape({super.key});

  @override
  State<StatefulWidget> createState() => _HomeDesktopLandscapeState();
}

class _HomeDesktopLandscapeState extends State<HomeDesktopLandscape> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        buildLeft(context).flexible(flex: 2),
        const SheetScreen().flexible(flex: 6),
        const PianoKeyboard().flexible(flex: 7),
      ].row(),
    );
  }

  Widget buildLeft(BuildContext ctx) {
    return [
      Column(
        children: [
          const DrawerHeader(child: SizedBox()).flexible(flex: 1),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: AutoSizeText(I18n.soundpack, maxLines: 1),
            trailing: const Icon(Icons.navigate_next),
            onTap: () {
              context.navigator.push(
                  MaterialPageRoute(builder: (ctx) => const SoundpackPage()));
            },
          )
        ],
      ).expanded(),
      const Spacer(),
      ListTile(
        leading: const Icon(Icons.settings),
        title: AutoSizeText(I18n.settings, maxLines: 1),
        onTap: () {
          context.navigator
              .push(MaterialPageRoute(builder: (ctx) => const SettingsPage()));
        },
      ),
      ListTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: AutoSizeText(I18n.about, maxLines: 1),
        onTap: () {
          context.navigator
              .push(MaterialPageRoute(builder: (ctx) => const AboutPage()));
        },
      ),
    ].column();
  }
}
