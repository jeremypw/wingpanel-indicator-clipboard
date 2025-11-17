/*
 * Copyright (c) 2024 Jeremy Wootten. (https://github.com/jeremypw)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Clipboard.HistoryWidget : Gtk.Box {
    private const string ACTIVE_DESCRIPTION = N_("Monitoring the clipboard contents");
    private const string PRIVACY_DESCRIPTION = N_("Privacy Mode is On");

    private Gee.HashSet<string> clipboard_text_set;
    private Gtk.ListBox clipboard_item_list;
    private string last_text = "";
    private uint wait_timeout = 0;
    private Granite.SwitchModelButton active_switch;
    private Gtk.Box privacy_widget;
    private Gtk.ScrolledWindow scroll_box;
    private Gtk.Stack stack;
    private unowned Gtk.Clipboard clipboard;

    public signal void close_request ();
    public signal void changed ();

    construct {
        orientation = VERTICAL;
        spacing = 6;

        active_switch = new Granite.SwitchModelButton (_("Clipboard Manager")) {
            description = _(ACTIVE_DESCRIPTION)
        };

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

        Clipboard.Indicator.settings.bind ("active", active_switch, "active", DEFAULT);

        clipboard_text_set = new Gee.HashSet<string> ();

        clipboard_item_list = new Gtk.ListBox () {
            selection_mode = SINGLE
        };
        clipboard_item_list.set_placeholder (new Gtk.Label (_("Clipboard Empty")));

        scroll_box = new Gtk.ScrolledWindow (null, null);
        scroll_box.max_content_height = 512;
        scroll_box.propagate_natural_height = true;
        scroll_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroll_box.add (clipboard_item_list);

        stack = new Gtk.Stack ();
        stack.add_named (scroll_box, "clipboard");
        stack.add_named (privacy_widget, "privacy");

        add (active_switch);
        add (stack);
        var clear_button = new Gtk.ModelButton () {
            text = _("Clear All Items"),
        };

        clear_button.clicked.connect (clear_history);

        add (new Gtk.Separator (HORIZONTAL));
        add (clear_button);

        show_all ();

        clipboard_item_list.row_activated.connect ((row) => {
            var clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
            var text = ((ItemRow)row).text;
            clipboard.set_text (text, -1);
            close_request ();
        });

        clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
    }

    ~HistoryWidget () {
        stop_waiting_for_text ();
    }

    // No notifications from clipboard? So poll it periodically for new text
    public void wait_for_text () {
        clipboard.owner_change.connect (on_clipboard_owner_change);
    }

    private void on_clipboard_owner_change () requires (clipboard != null) {
        if (clipboard.wait_is_text_available ()) {
            clipboard.request_text ((cb, text) => {
                if (!clipboard_text_set.contains (text)) {
                    clipboard_text_set.add (text);
                    var new_item = new ItemRow (text);
                    clipboard_item_list.prepend (new_item);
                    clipboard_item_list.select_row (new_item);
                    changed ();
                }
            });
        }
    }

    public void stop_waiting_for_text () requires (clipboard != null) {
        clipboard.owner_change.disconnect (on_clipboard_owner_change);
    }

    public void clear_history () {
        clipboard_text_set.clear ();
        clipboard_item_list.@foreach ((child) => {
            child.destroy ();
        });
    }

    public void set_privacy_mode (bool privacy_on) {
        active_switch.sensitive = !privacy_on;
        stack.visible_child_name = privacy_on ? "privacy" : "clipboard";
        if (privacy_on) {
            stop_waiting_for_text ();
            clear_history ();
            active_switch.description = _(PRIVACY_DESCRIPTION);
        } else {
            wait_for_text ();
            active_switch.description = _(ACTIVE_DESCRIPTION);
        }
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
            prettier_text = prettify (text);

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

         private string prettify (string text) {
            var prettier = new StringBuilder (text);
            var ellipsis = "…";
            var double_ellipsis = ellipsis + ellipsis;
            var replacements = prettier.replace ("  ", ellipsis);

            while (replacements > 0) {
                replacements = prettier.replace (double_ellipsis, ellipsis);
            }

            return prettier.str;
        }
    }

    public uint get_n_items () {
        return clipboard_text_set.size;
    }
}
