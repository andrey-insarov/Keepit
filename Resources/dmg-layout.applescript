-- Arranges the Finder window of the mounted DMG: icon view, app on the left, Applications on the right.
on run argv
    set volPath to item 1 of argv
    tell application "Finder"
        tell disk (POSIX file volPath as alias)
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 200, 760, 520}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 112
            set text size of theViewOptions to 13
            set position of item "Keepit.app" of container window to {150, 150}
            set position of item "Applications" of container window to {410, 150}
            close
            open
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
