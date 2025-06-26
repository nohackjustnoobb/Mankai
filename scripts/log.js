function log(mesg, from = "JS") {
  window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "log",
    params: {
      from: from,
      message: mesg,
    },
  });
}
