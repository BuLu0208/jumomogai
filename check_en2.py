# -*- coding: utf-8 -*-
content = open('TrollStore/TSAppTableViewController.m', 'r', encoding='utf-8').read()
lines = content.split('\n')
for i, line in enumerate(lines, 1):
    for kw in ['Cancel', 'Close', 'Uninstall App', 'Open', 'Show Details', 'Open with JIT', 'Confirm Uninstallation', 'Copy Debug', 'Respring']:
        if kw in line and '"' + kw + '"' in line:
            if not any(ord(c) > 0x4E00 for c in line):
                print("L%d: %s" % (i, line.strip()[:100]))
