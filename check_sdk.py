import urllib.request,json
req=urllib.request.Request('https://api.github.com/repos/theos/sdks/contents/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks',headers={'User-Agent':'Mozilla/5.0'})
data=json.loads(urllib.request.urlopen(req).read())
names = [x['name'] for x in data]
for needed in ['SpringBoardServices.framework','BackBoardServices.framework','FrontBoardServices.framework','MobileContainerManager.framework','RunningBoardServices.framework','Preferences.framework']:
    found = needed in names
    status = "YES" if found else "NO"
    print("  %s: %s" % (needed, status))
