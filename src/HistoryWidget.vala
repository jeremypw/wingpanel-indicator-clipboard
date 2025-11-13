/*
 * Copyright (c) 2024 Jeremy Wootten. (https://github.com/jeremypw)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Clipboard.HistoryWidget : Gtk.Box {
    private Gee.HashSet<string> clipboard_text_set;
    private Gtk.ListBox clipboard_item_list;
    private string last_text = "";
    private uint wait_timeout = 0;

    public signal void close_request ();

    construct {
        orientation = VERTICAL;
        spacing = 6;

        var active_switch = new Granite.SwitchModelButton (_("Clipboard Manager")) {
            description = _("Monitoring the clipboard contents")
        };

        Clipboard.Indicator.settings.bind ("active", active_switch, "active", DEFAULT);

        clipboard_text_set = new Gee.HashSet<string> ();

        clipboard_item_list = new Gtk.ListBox () {
            selection_mode = SINGLE
        };
        clipboard_item_list.set_placeholder (new Gtk.Label (_("Clipboard Empty")));
        var scroll_box = new Gtk.ScrolledWindow (null, null);
        scroll_box.max_content_height = 512;
        scroll_box.propagate_natural_height = true;
        scroll_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroll_box.add (clipboard_item_list);

        add (active_switch);
        add (scroll_box);
        show_all ();

        clipboard_item_list.row_activated.connect ((row) => {
            var clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
            var text = ((ItemRow)row).text;
            clipboard.set_text (text, -1);
            close_request ();
        });
    }

    ~HistoryWidget () {
        stop_waiting_for_text ();
    }

    // No notifications from clipboard? So poll it periodically for new text
    public void wait_for_text () {
        var clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
        wait_timeout = Timeout.add_full (Priority.LOW, 1000, () => {
            if (clipboard.wait_is_text_available ()) {
                clipboard.request_text ((cb, text) => {
                    if (text != last_text && !clipboard_text_set.contains (text)) {
                        last_text = text;
                        clipboard_text_set.add (text);
                        var new_item = new ItemRow (text);
                        clipboard_item_list.prepend (new_item);
                        clipboard_item_list.select_row (new_item);
                        clipboard_item_list.show_all ();
                    }
                });
            }

            return Source.CONTINUE;
        });
    }

    public void stop_waiting_for_text () {
        if (wait_timeout > 0) {
            Source.remove (wait_timeout);
        }
    }

    public void clear_history () {
        clipboard_text_set.clear ();
        clipboard_item_list.@foreach ((child) => {
            child.destroy ();
        });
    }

    private class ItemRow : Gtk.ListBoxRow {
        public string text { get; construct; }
        public string prettier_text { get; construct; }

        public ItemRow (string text) {
            Object (
                text: text
            );
        }

        construct {
            prettier_text = text.chomp ().chug ();

            var label = new Gtk.Label (prettier_text) {
                hexpand = true,
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.CENTER,
                xalign = 0.0f,
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6,
                ellipsize = Pango.EllipsizeMode.END,
                width_chars = 25,
                max_width_chars = 50,
                single_line_mode = true,
                tooltip_text = text
            };

            add (label);
        }
    }

    // Taken from the Code project (https://github.com/elementary/code)
    private class SettingSwitch : Gtk.Grid {
        public string label { get; construct; }
        public string settings_key { get; construct; }
        public string description { get; construct; }

        public SettingSwitch (string label, string settings_key, string description = "") {
            Object (
                description: description,
                label: label,
                settings_key: settings_key
            );
        }

        construct {
            var switch_widget = new Gtk.Switch () {
                valign = CENTER
            };

            var label_widget = new Gtk.Label (label) {
                halign = START,
                hexpand = true,
                mnemonic_widget = switch_widget
            };

            column_spacing = 12;
            attach (label_widget, 0, 0);
            attach (switch_widget, 1, 0, 1, 2);

            if (description != "") {
                var description_label = new Gtk.Label (description) {
                    halign = START,
                    wrap = true,
                    xalign = 0
                };
                description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                description_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

                attach (description_label, 0, 1);

                switch_widget.get_accessible ().accessible_description = description;
            }

            Clipboard.Indicator.settings.bind (settings_key, switch_widget, "active", DEFAULT);
        }
    }

}
