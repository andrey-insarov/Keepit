# How to clear the clipboard on a Mac

There is no *Clear Clipboard* command in macOS, but the clipboard only ever holds one item, so replacing it is the same as clearing it. Here are the ways to do that, and how to wipe a clipboard history if you use a clipboard manager.

## Replace the clipboard with nothing

**Copy an empty selection.** In any text field, select a single space (or nothing at all in some apps) and press `⌘C`. The previous item is gone; pasting now gives you a space or nothing.

**From Terminal.** This empties the clipboard outright:

```bash
pbcopy < /dev/null
```

Put it in a Shortcuts action or an Automator Quick Action if you want it on a key.

**Restart.** The clipboard lives in memory and does not survive logging out or restarting.

## Check what is on the clipboard

In Finder, *Edit → Show Clipboard* shows the current item, so you can confirm it is empty — or see what you are about to paste.

## Clear a clipboard history

A clipboard manager keeps more than the last item, so clearing the system clipboard does not clear its history. In [Keepit](index.html):

- **`⌥C`** or *Clear History* in the menu removes every history item. Templates are kept.
- Delete one item: hold `⇧` in the history menu and choose *Delete* from the item's submenu, or `⌃⌥⌫` for the newest item.
- **`⌥P`** pauses recording for ten minutes — for typing something you would rather not have in the history at all.
- Copies from password managers (1Password, Bitwarden, KeePassXC, Apple Passwords and others) and anything the copying app marks as concealed are never recorded in the first place.

If the history is encrypted (*Settings → Security*), locking Keepit with `⌥L` wipes the key from memory, and the files on disk stay unreadable until you unlock. Deleting Keepit and all its data is one command in *Settings → Advanced*.

## Related

- [How to see your clipboard history on a Mac](clipboard-history-mac.html)
- [How to paste as plain text on a Mac](paste-as-plain-text-mac.html)
- [Security: what Keepit stores and where](security.html)
