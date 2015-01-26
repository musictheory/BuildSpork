import sublime
import codecs

from ctypes import *
from ctypes.util import find_library

CFNotificationCallback = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)

CoreFoundation = cdll.LoadLibrary(find_library("CoreFoundation"))

kCFRunLoopDefaultMode = c_void_p.in_dll(CoreFoundation, "kCFRunLoopDefaultMode")

class CFRange(Structure):
    _fields_ = [
        ("location", c_long),
        ("length",   c_long)]

CFStringCreateWithBytes = CoreFoundation.CFStringCreateWithBytes
CFStringCreateWithBytes.restype = c_void_p
CFStringCreateWithBytes.argtypes = [ c_void_p, c_char_p, c_int, c_uint, c_ubyte ]

CFStringGetCharacters = CoreFoundation.CFStringGetCharacters
CFStringGetCharacters.argtypes = [ c_void_p, CFRange, c_void_p ]

CFNotificationCenterGetDistributedCenter = CoreFoundation.CFNotificationCenterGetDistributedCenter
CFNotificationCenterGetDistributedCenter.restype = c_void_p

CFNotificationCenterAddObserver = CoreFoundation.CFNotificationCenterAddObserver
CFNotificationCenterAddObserver.argtypes = [ c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_int ]

CFNotificationCenterRemoveObserver = CoreFoundation.CFNotificationCenterRemoveObserver
CFNotificationCenterRemoveObserver.argtypes = [ c_void_p, c_void_p, c_void_p, c_void_p ]

CFRunLoopRunInMode = CoreFoundation.CFRunLoopRunInMode
CFRunLoopRunInMode.argtypes = [ c_void_p, c_double, c_int ]

CFRelease = CoreFoundation.CFRelease
CFRelease.argtypes = [ c_void_p ]

CFShow = CoreFoundation.CFShow
CFShow.argtypes = [ c_void_p ]

CFDictionaryGetValue = CoreFoundation.CFDictionaryGetValue
CFDictionaryGetValue.argtypes = [ c_void_p, c_void_p ]
CFDictionaryGetValue.restype = c_void_p

CFStringGetLength = CoreFoundation.CFStringGetLength
CFStringGetLength.argtypes = [ c_void_p ]
CFStringGetLength.restype = c_long

# Helper Functions

def CreateString(string):
    b = bytes(string, 'utf-8')
    return CFStringCreateWithBytes(None, b, len(b), 0x08000100, False)

def Release(object):
    if (object):
        CFRelease(object)

def GetDictionaryValueAsString(cfDictionary, key):
    keyString = CreateString(key)
    cfString = CFDictionaryGetValue(cfDictionary, keyString)
    Release(keyString)

    characterCount = CFStringGetLength(cfString)
    range = CFRange(0, characterCount)
    b = create_string_buffer(characterCount * 2)

    CFStringGetCharacters(cfString, range, b)

    return codecs.decode(b.raw, "utf_16_le")


# Notifications

def handleDistributedNotification(center, observer, name, object, userInfo):
    if (userInfo):
        handleIncomingDictionary(userInfo)


class NotificationListener:
    def __init__(self):
        self.observer  = CFNotificationCallback(handleDistributedNotification)
        self.eventName = CreateString("net.musictheory.spork.event")
        center = CFNotificationCenterGetDistributedCenter()
        CFNotificationCenterAddObserver(center, self.observer, self.observer, self.eventName, None, 4)

    def __del__(self):
        center = CFNotificationCenterGetDistributedCenter()
        CFNotificationCenterRemoveObserver(center, self.observer, self.eventName, None)
        Release(self.eventName)

listener = NotificationListener()

def Tick():
    if (listener):
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, False)
        sublime.set_timeout(Tick, 100)    

sublime.set_timeout(Tick, 100)


# BuildSpork specific

projectToManagerMap = { }

class ProjectIssueManager():
    def __init__(self, window, project):
        self.window = window
        self.issueCount = 0
        self.panel = self.window.create_output_panel("BuildSpork")

        self.panel.settings().set("result_file_regex", "^([^:]*):([0-9]+):?([0-9]+)?:? (.*)$")
        self.panel.settings().set("result_line_regex", "")
        self.panel.settings().set("result_base_dir", project)
        self.panel.settings().set("word_wrap", True)
        self.panel.settings().set("line_numbers", False)
        self.panel.settings().set("gutter", False)
        self.panel.settings().set("scroll_past_end", False)
        self.panel.assign_syntax("Packages/Text/Plain text.tmLanguage")

    def handleStart(self):
        print("start")

        self.issueCount = 0
        self.panel.run_command("erase_view")

    def handleStop(self):
        if (self.issueCount == 0):
            self.window.run_command("hide_panel", { "panel": "output.BuildSpork" })

    def handleIssue(self, string):
        self.panel.run_command("append", { "characters": string + "\n" })

        self.issueCount = self.issueCount + 1
        if (self.issueCount > 0):
            self.window.run_command("show_panel", { "panel": "output.BuildSpork" })


def handleIncomingDictionary(dictionary):
    type    = GetDictionaryValueAsString(dictionary, "type")
    string  = GetDictionaryValueAsString(dictionary, "string")
    project = GetDictionaryValueAsString(dictionary, "project")

    if (not project):
        return

    manager = projectToManagerMap.get(project, None)

    if (not manager):
        for w in sublime.windows():
            project_name = w.project_file_name()

            if (not project_name):
                continue

            if (project_name.startswith(project)):
                manager = ProjectIssueManager(w, project)
                break

        if (manager):
            projectToManagerMap[project] = manager

    if (not manager):
        return

    if (type == "start"):
        manager.handleStart()

    elif (type == "stop"):
        manager.handleStop()

    elif (type == "issue"):
        path   = GetDictionaryValueAsString(dictionary, "path")
        line   = GetDictionaryValueAsString(dictionary, "line")
        issue  = GetDictionaryValueAsString(dictionary, "issue")

        manager.handleIssue(path + ":" + line + " " + issue)

