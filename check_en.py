# -*- coding: utf-8 -*-
import re

content = open('TrollStore/TSAppTableViewController.m', 'r', encoding='utf-8').read()

# Find all actionWithTitle strings
for m in re.finditer(r'actionWithTitle:@"([^"]+)"', content):
    text = m.group(1)
    if not any(ord(c) > 0x4E00 for c in text):  # no Chinese
        print("  EN: %s" % text)

# Find all alert titles/messages
for m in re.finditer(r'alertControllerWithTitle:@"([^"]+)"', content):
    text = m.group(1)
    if not any(ord(c) > 0x4E00 for c in text):
        print("  EN title: %s" % text)

for m in re.finditer(r'message:@"([^"]{3,})"', content):
    text = m.group(1)
    if not any(ord(c) > 0x4E00 for c in text):
        print("  EN msg: %s" % text[:80])

# Find "Cancel", "Close" etc
for keyword in ['Cancel', 'Close', 'Uninstall', 'Copy Debug', 'Respring']:
    if keyword in content:
        # count remaining English ones
        count = 0
        for m in re.finditer('@"' + keyword + '"', content):
            count += 1
        if count:
            print("  REMAINING '%s': %d" % (keyword, count))
