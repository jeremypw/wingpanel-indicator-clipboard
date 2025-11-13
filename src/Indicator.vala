/*
 * Copyright 2024 Jeremy Wootten. (https://github.com/jeremypw)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Clipboard.Indicator : Wingpanel.Indicator {
    public static GLib.Settings settings;
    private static GLib.Settings gnome_privacy_settings;
    private const string NORMAL_ICON_NAME = "edit-copy-symbolic";
    private const string STOPPED_ICON_NAME = "task-past-due-symbolic";
    private Gtk.Image panel_icon;
    private HistoryWidget history_widget;
    private Gtk.Box privacy_widget;
    public bool always_hide { get; set; }
    public bool privacy_on { get; set; }

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

        visible = true;

        settings = new GLib.Settings ("io.github.ellie_commons.indicator-clipboard");
        settings.bind ("always-hide", this, "always-hide", DEFAULT);

        var inactive_header_label = new Granite.HeaderLabel (_("The ClipboardManager is disabled"));
        var inactive_subheader_label = new Gtk.Label ("") {
            label = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("History is off in the Privacy and Security settings")),
            use_markup = true
        };
        privacy_widget = new Gtk.Box (VERTICAL, 0) {
            margin_start = 6,
            margin_end = 6
        };
        privacy_widget.add (inactive_header_label);
        privacy_widget.add (inactive_subheader_label);
        // Ensure correct appearance before showing
        get_display_widget ();
        get_widget ();
    }


    public override Gtk.Widget get_display_widget () {
        if (panel_icon == null) {
            panel_icon = new Gtk.Image.from_icon_name (NORMAL_ICON_NAME, Gtk.IconSize.SMALL_TOOLBAR);

            if (server_type == Wingpanel.IndicatorManager.ServerType.GREETER) {
                this.visible = false;
            } else {
                gnome_privacy_settings = new Settings ("org.gnome.desktop.privacy");
                gnome_privacy_settings.bind ("remember-recent-files", this, "privacy-on", GET | INVERT_BOOLEAN);
            }
        }

        return panel_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (history_widget == null &&
            server_type == Wingpanel.IndicatorManager.ServerType.SESSION) {

            history_widget = new HistoryWidget ();
            history_widget.close_request.connect (() => {
                close ();
            });

            this.notify["privacy-on"].connect (update_appearance);
            // this.notify["privacy-on"].connect (get_widget);
            this.notify["always-hide"].connect (update_appearance);
            update_appearance ();
        }

        // There doesn't seem to be a way of stopping Wingpanel showing the (blank) popover in the inactive state
        // So show informative label.
        return !privacy_on ? history_widget : privacy_widget;
    }

    public override void opened () {

    }

    public override void closed () {
    }

    private void update_appearance () {
        if (privacy_on || always_hide) {
            history_widget.clear_history ();
            history_widget.stop_waiting_for_text ();
            panel_icon.icon_name = STOPPED_ICON_NAME;
        } else if (!privacy_on && !always_hide) {
            history_widget.wait_for_text ();
            panel_icon.icon_name = NORMAL_ICON_NAME;
        }

        visible = !always_hide;
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Clipboard Indicator");
    return new Clipboard.Indicator (server_type);
}
