# -*- coding: utf-8 -*-
import re, os

files = [
    'TrollStore/TSRootViewController.m',
    'TrollStore/TSSettingsListController.m',
    'TrollStore/TSAppTableViewController.m',
    'TrollStore/TSInstallationController.m',
    'TrollStore/TSSettingsAdvancedListController.m',
    'TrollHelper/TSHRootViewController.m',
    'Shared/TSListControllerShared.m',
]

for f in files:
    content = open(f, 'r', encoding='utf-8').read()
    issues = []
    patterns = [
        r'actionWithTitle:@"([A-Z][a-z]+[A-Z][a-z]+)',
        r'alertControllerWithTitle:@"([A-Z][a-z]+)',
    ]
    for pat in patterns:
        for m in re.finditer(pat, content):
            word = m.group(1)
            issues.append(word)
    if issues:
        print("WARN %s: %s" % (os.path.basename(f), list(set(issues))))
    else:
        print("OK   %s" % os.path.basename(f))
