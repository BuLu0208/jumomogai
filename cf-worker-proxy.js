export default {
	async fetch(request) {
		const url = new URL(request.url);
		const headers = { 'User-Agent': 'Mozilla/5.0' };
		let githubURL = null;

		// jumomogai 代理（TrollStore 汉化版）
		if (url.pathname.startsWith('/jumomogai/')) {
			const path = url.pathname.replace('/jumomogai/', '');
			githubURL = `https://github.com/BuLu0208/jumomogai/releases/download/v2.1.1-custom/${path}`;
		}
		// kernelcache-mirror 代理
		else if (url.pathname.startsWith('/download/')) {
			const path = url.pathname.replace('/download/', '');
			githubURL = `https://github.com/BuLu0208/kernelcache-mirror/releases/download/${path}`;
		}
		// gta-trollhelper-builder 代理
		else if (url.pathname.startsWith('/troll/')) {
			const path = url.pathname.replace('/troll/', '');
			githubURL = `https://github.com/BuLu0208/gta-trollhelper-builder/releases/download/${path}`;
		}

		if (githubURL) {
			const resp = await fetch(githubURL, { headers, redirect: 'follow' });
			const respHeaders = new Headers(resp.headers);
			respHeaders.set('Access-Control-Allow-Origin', '*');
			return new Response(resp.body, {
				status: resp.status,
				statusText: resp.statusText,
				headers: respHeaders,
			});
		}

		return new Response('Proxy Service', { status: 200 });
	}
};
