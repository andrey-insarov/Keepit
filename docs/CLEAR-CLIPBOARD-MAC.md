# How to clear the clipboard on a Mac

"Clearing the clipboard" can mean three different things on a Mac, and each is done in a different place:

| What you clear | What it is |
|---|---|
| The system clipboard | The one item that `⌘V` pastes right now |
| Spotlight's clipboard history | The items macOS 26 Tahoe keeps for a while after you copied them |
| A clipboard manager's history | Everything an app such as Keepit has recorded |

Clearing one does not clear the others. Here is how to do each.

## 1. Clear the system clipboard

There is no *Clear Clipboard* command in macOS, but the clipboard only ever holds one item, so replacing it is the same as clearing it.

**Copy an empty selection.** In any text field, select a single space (or nothing at all in some apps) and press `⌘C`. The previous item is gone; pasting now gives you a space or nothing.

**From Terminal.** This empties the clipboard outright:

```bash
pbcopy < /dev/null
```

Put it in a Shortcuts action or an Automator Quick Action if you want it on a key.

**Restart.** The clipboard lives in memory and does not survive logging out or restarting.

**Check the result.** In Finder, *Edit → Show Clipboard* shows the current item, so you can confirm it is empty — or see what you are about to paste.

## 2. Clear Spotlight's clipboard history (macOS 26 Tahoe)

If you are on macOS 26, Spotlight keeps a history of what you copy (`⌘Space`, then `⌘4` to see it), and emptying the system clipboard does not touch it. To clear or limit it:

- **Clear it now.** Open *System Settings → Spotlight* and click *Clear Clipboard History*. The button arrived in macOS 26.1.
- **Let it expire.** Items are removed on their own after the window set in the same pane — 30 minutes, 8 hours (the default) or 7 days.
- **Switch it off.** Turning clipboard history off in *System Settings → Spotlight* stops recording.

On macOS 15 Sequoia and earlier there is no Spotlight history, so there is nothing to clear.

## 3. Clear a clipboard manager's history

A clipboard manager keeps its own record, independent of the system clipboard and of Spotlight. In [Keepit](/):

- **`⌥C`** or *Clear History* in the menu removes every history item. Templates are kept.
- Delete one item: hold `⇧` in the history menu and choose *Delete* from the item's submenu, or `⌃⌥⌫` for the newest item.
- **`⌥P`** pauses recording for ten minutes — for typing something you would rather not have in the history at all.
- Anything the copying app marks as concealed is not recorded in the first place, and copies made from password managers (1Password, Bitwarden, KeePassXC, Apple Passwords and others) are excluded by app — best effort, as the [security page](/security#what-is-not-recorded) explains.

If the history is encrypted (*Settings → Security*), locking Keepit with `⌥L` wipes the key from memory, and the files on disk stay unreadable until you unlock. Deleting Keepit and all its data is one command in *Settings → Advanced*.

## Related

- [How to see your clipboard history on a Mac](/clipboard-history-mac)
- [How to paste as plain text on a Mac](/paste-as-plain-text-mac)
- [Security: what Keepit stores and where](/security)
