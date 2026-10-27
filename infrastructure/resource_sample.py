"""Small Windows resource sampler without extra dependencies."""
import ctypes
from ctypes import wintypes
import os
import time


class ResourceSampler:
    def __init__(self):
        self.previous = None
        self.process_previous = {}

    def sample(self, pids):
        result = {'time': time.time()}
        if os.name != 'nt':
            return result
        class Memory(ctypes.Structure):
            _fields_ = [('length', ctypes.c_ulong), ('load', ctypes.c_ulong)] + [(n, ctypes.c_ulonglong) for n in
                ['physical', 'available', 'page_total', 'page_available', 'virtual', 'virtual_available', 'extended']]
        memory = Memory(); memory.length = ctypes.sizeof(Memory)
        kernel = ctypes.windll.kernel32
        kernel.GlobalMemoryStatusEx(ctypes.byref(memory))
        result.update(available_mib=round(memory.available/1048576), physical_mib=round(memory.physical/1048576),
                      load_percent=memory.load, logical_cpus=os.cpu_count())
        idle, system, user = ctypes.c_ulonglong(), ctypes.c_ulonglong(), ctypes.c_ulonglong()
        if kernel.GetSystemTimes(ctypes.byref(idle), ctypes.byref(system), ctypes.byref(user)):
            total = system.value + user.value
            if self.previous and total > self.previous[0]:
                result['system_cpu_percent'] = round(100 * (1 - (idle.value-self.previous[1])/(total-self.previous[0])), 1)
            self.previous = (total, idle.value)
        class Counters(ctypes.Structure):
            _fields_ = [('cb', wintypes.DWORD), ('faults', wintypes.DWORD)] + [(n, ctypes.c_size_t) for n in
                ['peak_working', 'working', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile', 'private']]
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(ctypes.c_ulonglong)] * 4
        ctypes.windll.psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
        processes = {}
        for pid in pids:
            handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)
            if not handle:
                continue
            try:
                counters = Counters(); counters.cb = ctypes.sizeof(Counters)
                values = {}
                if ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                    values.update(working_mib=round(counters.working/1048576), private_mib=round(counters.private/1048576))
                created, ended, system, user = [ctypes.c_ulonglong() for _ in range(4)]
                if kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(ended), ctypes.byref(system), ctypes.byref(user)):
                    cpu = (system.value + user.value) / 10000000
                    previous = self.process_previous.get(pid)
                    if previous and result['time'] > previous[0]:
                        values['cpu_cores'] = round((cpu-previous[1])/(result['time']-previous[0]), 2)
                    self.process_previous[pid] = (result['time'], cpu)
                processes[str(pid)] = values
            finally:
                kernel.CloseHandle(handle)
        result['processes'] = processes
        return result
