// SPDX-License-Identifier: Apache-2.0
// Test fixture: a real running Worker whose synthesis request never resolves.
const requestID = new URL(self.location.href).searchParams.get('request');
self.postMessage({type: 'ready', requestID});
self.onmessage = () => {};
