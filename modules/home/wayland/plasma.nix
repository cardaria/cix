{
  cixPkgs,
  config,
  dotfile,
  osConfig,
  ...
}:
let
  panelHeight = 30;
  panelFloating = true;

  # normalpanel, autohide, dodgewindows or windowsgobelow
  panelHiding = "windowsgobelow";

  # Logical px; 8 is the floating panel's own margin
  gap = 8;

  # Reserved strip by mode (measured): normalpanel = bar height, windowsgobelow = none.
  # autohide and dodgewindows overlay windows and reserve nothing
  topGap =
    if panelHiding == "windowsgobelow" then
      panelHeight + (if panelFloating then 2 * gap else gap)
    else if panelHiding == "normalpanel" && panelFloating then
      2 * gap
    else
      gap;
in
{
  home.packages = [ cixPkgs.krohnkite ];
  home.sessionVariables.TERMINAL = "ghostty";

  # Matched by EDID identity; KWin writes display changes back through the link
  xdg.configFile."kwinoutputconfig.json".source =
    dotfile "kwin/${osConfig.networking.hostName}/kwinoutputconfig.json";

  programs.plasma = {
    enable = true;

    configFile.dolphinrc.General.GlobalViewProps = true;
    configFile.dolphinrc.MainWindow.MenuBar = "Disabled";
    configFile.dolphinrc."KFileDialog Settings" = {
      "Places Icons Auto-resize" = false;
      "Places Icons Static Size" = 22;
    };
    dataFile."dolphin/view_properties/global/.directory".Dolphin = {
      Version = 4;
      ViewMode = 1;
    };

    workspace = {
      colorScheme = "BreezeLight";
      iconTheme = "Colloid-cix";
      widgetStyle = "Breeze";
      cursor.theme = "breeze_cursors";
      windowDecorations = {
        library = "org.kde.breeze";
        theme = "Breeze";
      };
      wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/art-institute-of-chicago-ytS2Y6cI9sY-unsplash.jpg";
    };
    configFile.kdeglobals = {
      General = {
        UseSystemBell = true;
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };
      KDE = {
        AnimationDurationFactor = 0.5;
        SmoothScroll = false;
        contrast = 4;
        frameContrast = 0.2;
      };
      "KFileDialog Settings" = {
        "Allow Expansion" = false;
        "Automatically select filename extension" = true;
        "Breadcrumb Navigation" = true;
        "Decoration position" = 2;
        "Show Full Path" = false;
        "Show Inline Previews" = true;
        "Show Preview" = false;
        "Show Speedbar" = true;
        "Show hidden files" = false;
        "Sort by" = "Name";
        "Sort directories first" = true;
        "Sort hidden files last" = false;
        "Sort reversed" = false;
        "Speedbar Width" = 140;
        "View Style" = "DetailTree";
      };
    };

    input.keyboard.layouts = [ { layout = "se"; } ];
    kwin.virtualDesktops = {
      number = 4;
      rows = 1;
    };
    kwin.effects.desktopSwitching.animation = "fade";
    kwin.effects.shakeCursor.enable = false;
    # plasma-manager has no Krohnkite options
    configFile.kwinrc = {
      Plugins.krohnkiteEnabled = true;
      MouseBindings = {
        CommandAllKey = "Meta";
        CommandAll2 = "Minimize";
        CommandAllWheel = "Previous/Next Desktop";
      };
      Windows = {
        BorderSnapZone = 0;
        WindowSnapZone = 0;
        DelayFocusInterval = 0;
      };
      "Script-krohnkite" = {
        soleWindowWidth = 60;
        soleWindowHeight = 100;

        screenGapLeft = gap;
        screenGapRight = gap;
        screenGapTop = topGap;
        screenGapBottom = gap;
        screenGapBetween = gap;
      };
    };

    panels = [
      {
        location = "top";
        height = panelHeight;
        alignment = "center";
        lengthMode = "fill";
        hiding = panelHiding;
        floating = panelFloating;
        opacity = "adaptive";
        widgets = [
          "org.kde.plasma.kickoff"
          {
            panelSpacer = {
              expanding = false;
              length = 20;
            };
          }
          { pager.general.selectingCurrentVirtualDesktop = "showDesktop"; }
          {
            panelSpacer = {
              expanding = false;
              length = 20;
            };
          }
          {
            iconTasks.launchers = [
              "preferred://filemanager"
              "preferred://browser"
            ];
          }
          {
            panelSpacer = {
              expanding = false;
              length = 20;
            };
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items = {
              hidden = [
                "1Password_status_icon_1"
                "spotify-client"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.brightness"
              ];
              extra = [
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.manage-inputmethod"
                "org.kde.plasma.mediacontroller"
                "org.kde.plasma.notifications"
                "org.kde.kscreen"
                "org.kde.plasma.battery"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.keyboardlayout"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.volume"
                "org.kde.plasma.weather"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.brightness"
              ];
            };
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];

    shortcuts = {
      "services/org.kde.konsole.desktop"._launch = [ ];
      "services/com.mitchellh.ghostty.desktop"._launch = [
        "Ctrl+Alt+T"
        "Meta+Return"
      ];
      "services/brave-origin.desktop"._launch = "Meta+B";
      "services/org.kde.dolphin.desktop"._launch = [
        "Meta+E"
        "Meta+A"
      ];
      "services/org.kde.krunner.desktop"._launch = [
        "Alt+Space"
        "Alt+F2"
        "Search"
        "Meta+D"
      ];
      "services/systemsettings.desktop"._launch = [
        "Tools"
        "Meta+I"
        "Meta+,"
      ];
      "services/org.kde.spectacle.desktop".FullScreenScreenShot = [
        "Shift+Print"
        "Ctrl+Print"
      ];

      ksmserver."Log Out" = [
        "Ctrl+Alt+Del"
        "Meta+Escape"
        "Meta+Shift+E"
      ];

      kwin = {
        "Window Close" = [
          "Meta+Q"
          "Alt+F4"
        ];
        "Window Fullscreen" = "Meta+F";
        "Overview" = [
          "Meta+Tab"
          "Meta+W"
        ];
        "Walk Through Windows" = "Alt+Tab";

        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";
        # KWin consumes Shift into the symbol: Meta+Shift+1 arrives as Meta+! on the se layout
        "Window to Desktop 1" = "Meta+!";
        "Window to Desktop 2" = "Meta+\"";
        "Window to Desktop 3" = "Meta+#";
        "Window to Desktop 4" = "Meta+¤";

        KrohnkiteFocusLeft = "Meta+Left";
        KrohnkiteFocusRight = "Meta+Right";
        KrohnkiteFocusUp = "Meta+Up";
        KrohnkiteFocusDown = "Meta+Down";
        KrohnkiteShiftLeft = "Meta+Shift+Left";
        KrohnkiteShiftRight = "Meta+Shift+Right";
        KrohnkiteShiftUp = "Meta+Shift+Up";
        KrohnkiteShiftDown = "Meta+Shift+Down";
        KrohnkiteShrinkWidth = "Meta+-";
        KrohnkitegrowWidth = "Meta+=";
        KrohnkiteToggleFloat = "Meta+Space";
        KrohnkiteNextLayout = "Meta+M";
        KrohnkitePreviousLayout = "Meta+Shift+M";

        # Plasma defaults on keys bound above or kept by Krohnkite
        "Window Quick Tile Left" = [ ];
        "Window Quick Tile Right" = [ ];
        "Window Quick Tile Top" = [ ];
        "Window Quick Tile Bottom" = [ ];
        "Window to Next Screen" = [ ];
        "Window to Previous Screen" = [ ];
        "Show Desktop" = [ ];
        view_zoom_in = "Meta++";
        view_zoom_out = [ ];
        "Edit Tiles" = [ ];
        # Krohnkite defaults on keys Plasma or the bindings above use
        KrohnkiteSetMaster = [ ];
        KrohnkiteIncrease = [ ];
        KrohnkiteDecrease = [ ];
        KrohnkiteFocusNext = [ ];
        KrohnkiteFocusPrev = [ ];
        KrohnkiteRotate = [ ];
        KrohnkiteRotatePart = [ ];
        KrohnkiteMonocleLayout = [ ];
      };

      plasmashell = {
        "activate task manager entry 1" = [ ];
        "activate task manager entry 2" = [ ];
        "activate task manager entry 3" = [ ];
        "manage activities" = [ ];
        "next activity" = [ ];
      };
    };
  };
}
