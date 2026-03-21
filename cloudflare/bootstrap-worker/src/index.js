const RAW_BOOTSTRAP_URL =
  "https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh";

function methodNotAllowed() {
  return new Response("Method Not Allowed\n", {
    status: 405,
    headers: {
      "Allow": "GET, HEAD",
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-cache",
    },
  });
}

function upstreamFailure(status) {
  return new Response("Upstream bootstrap fetch failed.\n", {
    status,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-cache",
    },
  });
}

export default {
  async fetch(request) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return methodNotAllowed();
    }

    const upstream = await fetch(RAW_BOOTSTRAP_URL, {
      method: request.method,
      headers: {
        "User-Agent": "obslove-bootstrap-worker",
      },
      redirect: "follow",
    });

    if (!upstream.ok) {
      return upstreamFailure(502);
    }

    const headers = new Headers(upstream.headers);
    headers.set("Content-Type", "text/plain; charset=utf-8");
    headers.set("Cache-Control", "no-cache");
    headers.set("X-Bootstrap-Source", "github-main-install-sh");

    return new Response(request.method === "HEAD" ? null : upstream.body, {
      status: upstream.status,
      headers,
    });
  },
};
