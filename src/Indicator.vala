/*
 * Copyright 2024 Jeremy Wootten. (https://github.com/jeremypw)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Clipboard.Indicator : Wingpanel.Indicator {
    private static GLib.Settings settings;
    private static GLib.Settings gnome_privacy_settings;
    private Gtk.Image panel_icon;
    private HistoryWidget history_widget;

    public Wingpanel.IndicatorManager.ServerType server_type { get; construct set; }

    public Indicator (Wingpanel.IndicatorManager.ServerType indicator_server_type) {
        Object (code_name: "clipboard",
                server_type: indicator_server_type);
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        settings = new GLib.Settings ("io.github.ellie_commons.indicator-clipboard");
        settings.bind ("visible", this, "visible", GLib.SettingsBindFlags.DEFAULT);
        gnome_privacy_settings = new Settings ("org.gnome.desktop.privacy");
        gnome_privacy_settings.bind ("remember-recent-files", this, "visible", GET);
    }


    public override Gtk.Widget get_display_widget () {
        if (panel_icon == null) {
            panel_icon = new Gtk.Image.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

            if (server_type == Wingpanel.IndicatorManager.ServerType.GREETER) {
                this.visible = false;
            } else {
                this.notify["visible"].connect (() => {
                    warning ("visible changed to %s", visible.to_string ());
                    if (!visible) {
                        ((HistoryWidget) (get_widget ())).clear_history ();
                    }
                });
            }
        }

        get_widget ();
        return panel_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (history_widget == null &&
            server_type == Wingpanel.IndicatorManager.ServerType.SESSION) {
                history_widget = new HistoryWidget ();
                history_widget.close_request.connect (() => {
                    close ();
                });
                history_widget.wait_for_text ();
        }

        return history_widget;
    }

    public override void opened () {
    }

    public override void closed () {
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Clipboard Indicator");
    return new Clipboard.Indicator (server_type);
}
