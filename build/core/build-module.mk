# Copyright (C) 2010 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

$(call check-defined-LOCAL_MODULE,$(LOCAL_BUILD_SCRIPT))
$(call check-LOCAL_MODULE,$(LOCAL_MAKEFILE))

# This file is used to record the LOCAL_XXX definitions of a given
# module. It is included by BUILD_STATIC_LIBRARY, BUILD_SHARED_LIBRARY
# and others.
#
LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifndef LOCAL_MODULE_CLASS
$(call __ndk_info,$(LOCAL_MAKEFILE):$(LOCAL_MODULE): LOCAL_MODULE_CLASS definition is missing !)
$(call __ndk_error,Aborting)
endif

$(if $(call module-class-check,$(LOCAL_MODULE_CLASS)),,\
$(call __ndk_info,$(LOCAL_MAKEFILE):$(LOCAL_MODULE): Unknown LOCAL_MODULE_CLASS value: $(LOCAL_MODULE_CLASS))\
$(call __ndk_error,Aborting)\
)

# CrystaX: force -Wl,--eh-frame-hdr for static executables
ifneq (,$(and $(filter -static,$(LOCAL_LDFLAGS)),$(if $(filter -Wl,--eh-frame-hdr,$(LOCAL_LDFLAGS)),,yes)))
LOCAL_LDFLAGS += -Wl,--eh-frame-hdr
endif

$(call module-add,$(LOCAL_MODULE))
