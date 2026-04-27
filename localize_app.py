# -*- coding: utf-8 -*-

filepath = 'TrollStore/TSAppTableViewController.m'
content = open(filepath, 'r', encoding='utf-8').read()

replacements = [
    # Navigation / menu
    ('"Install IPA File"', '"从文件安装 IPA"'),
    ('"Install from URL"', '"从 URL 安装"'),
    ('"Install"', '"安装"'),
    ('"Cancel"', '"取消"'),

    # App action sheet
    ('"Open"', '"打开"'),
    ('"Open with JIT"', '"启用 JIT 打开"'),
    ('"Show Details"', '"查看详情"'),
    ('"Switch to \\"%@\\" Registration"', '"切换为「%@」注册"'),
    ('"Uninstall App"', '"卸载应用"'),
    ('"Uninstall"', '"卸载"'),
    ('"Close"', '"关闭"'),
    ('"Respring"', '"注销"'),

    # Error messages
    ('"This app was not able to launch because it has a \\"User\\" registration state, register it as \\"System\\" and try again."',
     '"此应用无法启动，因为它的注册状态为「用户」，请将其注册为「系统」后重试。"'),
    ('"Failed to open %@"', '"无法打开 %@"'),
    ('@"Error"', '@"错误"'),
    ('"Error enabling JIT: trollstorehelper returned %d"', '"启用 JIT 失败：trollstorehelper 返回 %d"'),
    ('"Parse Error %ld"', '"解析错误 %ld"'),
    ('"Error downloading app: %@', '"下载应用时出错：%@'),

    # Registration switch
    ('"Confirm Uninstallation"', '"确认卸载"'),
    ("Uninstalling the app '%@' will delete the app and all data associated to it.",
     "卸载应用「%@」将删除该应用及其所有关联数据。"),
    ('"Copy Debug Log"', '"复制调试日志"'),
    ('The app has been switched to the "System" registration state and will become launchable again after a respring.',
     '应用已切换为「系统」注册状态，注销 SpringBoard 后即可恢复启动。'),
    ('"Reboot Required"', '"需要重启"'),
    ('"Reboot Now"', '"立即重启"'),
    ('"Warning"', '"警告"'),
    ('"Force Installation"', '"强制安装"'),
    ('"Install Error %d"', '"安装错误 %d"'),
    ('"Downloading"', '"下载中"'),
    ('"Installing"', '"安装中"'),
]

ok_count = 0
miss_count = 0
for old, new in replacements:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        ok_count += 1
    else:
        miss_count += 1
        print("  MISS: %s" % old[:60])

print("Replaced: %d, Missed: %d" % (ok_count, miss_count))

# Handle the long registration explanation block
# Find the specific pattern
import re

# The "Switching to User" long message - find it by surrounding context
pattern = r'"Switching this app to a \\"User\\" registration will make it unlaunchable[^"]*"'
match = re.search(pattern, content)
if match:
    old_text = match.group(0)
    new_text = '"将此应用切换为「用户」注册后，下次注销 SpringBoard 将无法启动，因为 TrollStore 利用的漏洞仅影响「系统」注册的应用。\\n此选项的目的是让应用临时在设置中显示，以便调整设置后切换回「系统」注册。此外，「用户」注册状态也可用于临时修复 iTunes 文件共享。\\n完成设置更改后，需要在 TrollStore 中将应用切换回「系统」状态才能再次启动。"'
    content = content.replace(old_text, new_text)
    print("OK: long registration explanation")
else:
    print("MISS: long registration explanation")

# Switching title
old_st = 'Switching \'%@\' to "User" Registration'
new_st = '将「%@」切换为「用户」注册'
if old_st in content:
    content = content.replace(old_st, new_st)
    print("OK: switching title")
else:
    print("MISS: switching title")

# Switched to System title
old_ss = 'Switched \'%@\' to "System" Registration'
new_ss = '已将「%@」切换为「系统」注册'
if old_ss in content:
    content = content.replace(old_ss, new_ss)
    print("OK: switched to system title")
else:
    print("MISS: switched to system title")

# Switch to User button
old_su = 'Switch to "User"'
new_su = '切换为「用户」'
if old_su in content:
    content = content.replace(old_su, new_su)
    print("OK: switch to user button")
else:
    print("MISS: switch to user button")

# Switch to System button
old_ssys = 'Switch to "System"'
new_ssys = '切换为「系统」'
if old_ssys in content:
    content = content.replace(old_ssys, new_ssys)
    print("OK: switch to system button")
else:
    print("MISS: switch to system button")

open(filepath, 'w', encoding='utf-8').write(content)
print("\nDone!")
