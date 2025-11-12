/*
 * Copyright 2024 Jeremy Wootten. (https://github.com/jeremypw)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Clipboard.Indicator : Wingpanel.Indicator {
    private static GLib.Settings settings;
    private Gtk.Widget display_widget;
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
    }

    public override Gtk.Widget get_display_widget () {
        if (display_widget == null) {
            var panel_icon = new Gtk.Image.from_icon_name (
                "edit-copy-symbolic",
                Gtk.IconSize.SMALL_TOOLBAR
            );

            display_widget = new Gtk.EventBox () {
                child = panel_icon
            };

            display_widget.events = BUTTON_PRESS_MASK;


            if (server_type == Wingpanel.IndicatorManager.ServerType.GREETER) {
                this.visible = false;
            } else {
                this.visible = true;
            }

            get_widget (); // Initialize history widget
            history_widget.changed.connect (update_tooltip);

            // EventController does not work?
            display_widget.button_press_event.connect ((event) => {
                if (event.button == 3) {
                    history_widget.clear_history ();
                    return true;
                }

                return false;
            });

            display_widget.show_all ();
            update_tooltip ();
        }

        return display_widget;
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

    private void update_tooltip () {
        uint n_items = history_widget.get_n_items ();
        string description;
        if (n_items > 0) {
            description = ngettext (
                _("Clipboard Manager: %u item"),
                _("Clipboard Manager: %u items"),
                n_items
            ).printf (n_items);
        } else {
            description = _("Clipboard Manager: Empty");
        }

        if (n_items > 0) {
            string accel_label = n_items > 0 ? _("Middle-click to clear") : "";
            accel_label = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (accel_label);
            display_widget.tooltip_markup = "%s\n%s".printf (description, accel_label);
        } else {
            display_widget.tooltip_markup = "%s".printf (description);
        }
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Clipboard Indicator");
    return new Clipboard.Indicator (server_type);
}
