# This library provides functions for building ncurses-esque menus in bash. It
# makes use of the `tput` command to get terminal information, and the `read`
# command to get user input. It also uses the `trap` command to handle signals.
#
# ## Usage
#
# To use this library, source it in your script:
#
# ```bash
# source "${HOME}/.bash/lib/menu.sh"
# ```
#
# ## Functions
#
# ### `menu-config`
#
# This function is used to build a menu configuration. It takes a variable name
# as its argument and a list of configuration options.
#
# #### Usage
# menu-config <name> [options]
#
# #### Options
# - `--title <title>`: The title of the menu
# - `--prompt <prompt>`: The prompt to display to the user
# - `--header <header>`: A header to display above the menu
# - `--footer <footer>`: A footer to display below the menu
# - `--show-help-keybinding`: Show the help keybinding in the footer
# - `--show-help-text`: Show the help text in the footer 
# - `--style <ansi>`: The default style to use for all menu items
# - `--style-text <ansi>`: The default style to use for all menu text
# - `--style-header <ansi>`: The style to use for the header
# - `--style-footer <ansi>`: The style to use for the footer
# - `--style-prompt <ansi>`: The style to use for the prompt
# - `--style-selected <ansi>`: The style to use for the selected item
# - `--style-disabled <ansi>`: The style to use for disabled items
# - `--style-checked <ansi>`: The style to use for checked items
# - `--item <id>:<text>`: Add an item to the menu
#
# #### Items
#
# Items are added to the menu using the `--item` option. Each item is configured
# using the `menu-item-config` function.
#
# ##### Item IDs
#
# Item IDs are used to identify items in the menu. They are also used to
# determine which item is selected when the menu is first displayed. If no item
# ID is specified, then the item's index in the menu is used as the ID.
#
# ### `menu-item-config`
#
# This function is used to build a menu item configuration. It takes two
# arguments: the menu name and the item ID.
#
# #### Usage
# menu-item-config <name> <id> [options]
#
# #### Options
# - `--text <text>`: The text to display for the item
# - `--style <ansi>`: The style to use for the item
# - `--type <type>`: The type of item
# - `--group <group>`: The group the item belongs to
# - `--checked`: Check the item by default
# - `--disabled`: Disable the item
# - `--max-chars <int>`: The maximum number of characters allowed for text
#   fields
# - `--allowed-chars <chars>`: The characters allowed for text fields
# - `--default <value>`: The default value for text fields
# - `--on-change <command>`: The command to run when the item changes
# - `--on-select <command>`: The command to run when the item is selected
# - `--on-deselect <command>`: The command to run when the item is deselected
# - `--on-check <command>`: The command to run when the item is checked
# - `--on-uncheck <command>`: The command to run when the item is unchecked
# - `--on-exit <command>`: The command to run when the menu exits if the item is
#   selected
# - `--menu <name>`: For menu items, the name of the menu to run
#
# ##### Item Types
#
# Item types are used to determine how the item is displayed in the menu. The
# following item types are supported:
#
# - `checkbox`: A checkbox item. The item's text is displayed to the right of
#   the checkbox. The checkbox is checked if the item's ID is in the `checked`
#   array.
# - `radio`: A radio item. The item's text is displayed to the right of the
#   radio button. The radio button is checked if the item's ID is equal to the
#   `selected` variable.
# - `text`: A text field item. The item's text is displayed to the right of the
#   text field. The text field is disabled if the item's ID is in the `disabled`
#   array.
# - `number`: A text field item which allows only numeric input.
# - `password`: A text field item which hides the input.
# - `menu`: A menu item. The item's text is displayed to the right of the menu
#   indicator. Selecting this item will run the defined menu.
#
# ##### Item Groups
#
# Item groups are used to place items together in the menu. For radio items,
# groups also restrict the user to selecting only one item in the group at a
# time. If no group is specified, then the item will be placed in the default
# group.
#
# ### `menu-group-config`
#
# This function is used to build a menu group configuration. It takes two
# arguments: the menu name and the group ID.
#
# #### Usage
# menu-group-config <name> <id> [options]
#
# #### Options
# - `--type <type>`: The type of group
# - `--min <int>`: The minimum number of items that must be selected
# - `--max <int>`: The maximum number of items that can be selected
# - `--on-select <command>`: The command to run when an item is selected
# - `--on-deselect <command>`: The command to run when an item is deselected
# - `--header <header>`: A header to display above the group
# - `--style <ansi>`: The default style to use for all group items
# - `--style-text <ansi>`: The default style to use for all group text
# - `--style-header <ansi>`: The style to use for the group header
# - `--style-selected <ansi>`: The style to use for the selected group items
# - `--style-disabled <ansi>`: The style to use for disabled group items
# - `--style-checked <ansi>`: The style to use for checked group items
# - `--item <id>:<text>`: Add an item to the group
#
# #### Items
#
# Items can be added to a group through either `menu-item-config` or
# `menu-group-config`. It is unnecessary to add items to a group through both
# functions, but doing so will not cause any issues.
#
# ### `menu-run`
#
# This function is used to run a menu. It takes a menu name as its argument.
# Upon exiting, it will set the `MENU_RESULT` variable to an associative array
# containing the results of the user input.
#
# #### Usage
# menu-run <name>
#
# #### Return Value
#
# The `MENU_RESULT` variable will be set to an associative array whose keys are
# the item IDs and whose values are the item values. The possible values are:
#
# - checkbox: `true` if the checkbox is checked, `false` otherwise
# - radio: `true` if the radio button is checked, `false` otherwise
# - text: the text entered by the user
#
# #### Usage
# menu-run <name>
#
# ### `menu-config-get`
#
# This function is used to get the configuration settings for a menu. It takes
# a menu name as its first argument and an optional configuration option as its
# second argument. If no configuration option is specified, then all of the
# configuration settings are returned.
#
# ## Examples
#
# ### Simple Menu
#
# ```bash
# #!/usr/bin/env bash
#
# source "${HOME}/.bash/lib/menu.sh"
#
# menu-config "main" \
#     --title "Main Menu" \
#     --prompt "Select one or more actions to run: " \
#     --item reboot:"Reboot" \
#     --item shutdown:"Shutdown" \
#     --item exit:"Exit"
#
# menu-item-config "main" "reboot" \
#     --type radio \
#     --group "shutdown_group" \
#     --on-exit "reboot"
#
# menu-item-config "main" "shutdown" \
#     --type radio \
#     --group "shutdown_group" \
#     --on-exit "shutdown -h now"
#
# menu-run "main"
#
# if [[ "${MENU_RESULT[exit]}" == "true" ]]; then
#     exit 0
# fi
# ```
#
# ### Nested Menus
#
# ```bash
# #!/usr/bin/env bash
#
# source "${HOME}/.bash/lib/menu.sh"
#
# menu-config "main" \
#     --title "Main Menu" \
#     --item settings:"Settings" \
#     --item exit:"Exit"
#
# menu-item-config "main" "settings" \
#     --type menu \
#     --menu "settings"
#
# menu-config "settings" \
#     --title "Settings" \
#     --item name:"Name" \
#     --item email:"Email" \
#     --item back:"Back"
#
# menu-item-config "settings" "name" \