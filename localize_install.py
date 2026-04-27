# -*- coding: utf-8 -*-
import re

content = open('TrollStore/TSInstallationController.m', 'r', encoding='utf-8').read()
replacements = [
    ('"Installing"', '"安装中"'),
    ('"Downloading"', '"下载中"'),
    ('"Install Error %d"', '"安装错误 %d"'),
    ('"Error downloading app: %@', '"下载应用时出错：%@'),
    ('"Reboot Required"', '"需要重启"'),
    ('"Reboot Now"', '"立即重启"'),
    ('"Warning"', '"警告"'),
    ('"Force Installation"', '"强制安装"'),
    ('"Install"', '"安装"'),
    ('"Cancel"', '"取消"'),
    ('"Close"', '"关闭"'),
    ('"Copy Debug Log"', '"复制调试日志"'),
    ('"Error"', '"错误"'),
    ('"Parse Error %ld"', '"解析错误 %ld"'),
]

for old, new in replacements:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print("OK (%d): %s" % (count, old))
    else:
        print("MISS: %s" % old)

open('TrollStore/TSInstallationController.m', 'w', encoding='utf-8').write(content)
print("Done!")
