import sublime
import codecs
import subprocess

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

def CreateCFString(string):
    b = bytes(string, 'utf-8')
    return CFStringCreateWithBytes(None, b, len(b), 0x08000100, False)

def Release(object):
    if (object):
        CFRelease(object)

def GetStringFromCFString(cfString):
    characterCount = CFStringGetLength(cfString)
    range = CFRange(0, characterCount)
    b = create_string_buffer(characterCount * 2)

    CFStringGetCharacters(cfString, range, b)

    return codecs.decode(b.raw, "utf_16_le")

def GetDictionaryValueAsString(cfDictionary, key):
    keyString = CreateCFString(key)
    cfString = CFDictionaryGetValue(cfDictionary, keyString)
    Release(keyString)

    return GetStringFromCFString(cfString)


# Notifications

def handleDistributedNotification(center, observer, name_CFString, object, userInfo):
    name = GetStringFromCFString(name_CFString)

    if (userInfo):
        if (name == "net.musictheory.spork.event"):
            handleSporkEvent(userInfo)
        elif (name == "net.musictheory.spork.open"):
            handleSporkOpen(userInfo)


class NotificationListener:
    def __init__(self):
        self.observer  = CFNotificationCallback(handleDistributedNotification)

        self.eventString = CreateCFString("net.musictheory.spork.event")
        self.openString  = CreateCFString("net.musictheory.spork.open")

        center = CFNotificationCenterGetDistributedCenter()
        CFNotificationCenterAddObserver(center, self.observer, self.observer, self.eventString, None, 4)
        CFNotificationCenterAddObserver(center, self.observer, self.observer, self.openString,  None, 4)

    def __del__(self):
        center = CFNotificationCenterGetDistributedCenter()

        CFNotificationCenterRemoveObserver(center, self.observer, self.eventString, None)
        CFNotificationCenterRemoveObserver(center, self.observer, self.openString,  None)

        Release(self.eventString)
        Release(self.openString)

listener = NotificationListener()

def Tick():
    if (listener):
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, False)
        sublime.set_timeout(Tick, 100)    

sublime.set_timeout(Tick, 100)


# BuildSpork specific

def GetWindow(project_name):
    for w in sublime.windows():
        window_project_name = w.project_file_name()

        if (not window_project_name):
            continue

        if (window_project_name.startswith(project_name)):
            return w

    return None


projectToManagerMap = { }

class ProjectIssueManager():
    def __init__(self, window, project):
        self.window = window
        self.issueCount = 0
        
        panel = self.window.create_output_panel("BuildSpork")
        panel.settings().set("result_file_regex", "^([^:]*):([0-9]+):?([0-9]+)?:? (.*)$")
        panel.settings().set("result_line_regex", "")
        panel.settings().set("result_base_dir", project)
        panel.settings().set("word_wrap", True)
        panel.settings().set("line_numbers", False)
        panel.settings().set("gutter", False)
        panel.settings().set("scroll_past_end", False)
        panel.assign_syntax("Packages/Text/Plain text.tmLanguage")

        self.panel = panel

    def handleStart(self):
        print("handleStart", self.panel)
        self.issueCount = 0
        self.panel.run_command("select_all")
        self.panel.run_command("right_delete")


    def handleStop(self):
        print("handleStop")

        if (self.issueCount == 0):
            self.window.run_command("hide_panel", { "panel": "output.BuildSpork" })

    def handleIssue(self, string):
        self.panel.run_command("append", { "characters": string + "\n" })

        self.issueCount = self.issueCount + 1
        if (self.issueCount > 0):
            self.window.run_command("show_panel", { "panel": "output.BuildSpork" })


def handleSporkOpen(dictionary):
    project = GetDictionaryValueAsString(dictionary, "project")
    path    = GetDictionaryValueAsString(dictionary, "path")
    line    = GetDictionaryValueAsString(dictionary, "line")

    window = GetWindow(project)
    fullPath = project + "/" + path

    if (not window):
        for w in sublime.windows():
            if (w.find_open_file(fullPath)):
                window = w;
                break;

    if (not window):
        sublime.run_command("open_file", { "file": fullPath })

        for w in sublime.windows():
            if (w.find_open_file(fullPath)):
                window = w;
                break;

    if (not window):
        return

    window.open_file(fullPath + ":" + line, sublime.ENCODED_POSITION)


def handleSporkEvent(dictionary):
    type    = GetDictionaryValueAsString(dictionary, "type")
    string  = GetDictionaryValueAsString(dictionary, "string")
    project = GetDictionaryValueAsString(dictionary, "project")

    if (not project):
        return

    manager = projectToManagerMap.get(project, None)

    if (not manager):
        w = GetWindow(project)

        if (w):
            manager = ProjectIssueManager(w, project)
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

