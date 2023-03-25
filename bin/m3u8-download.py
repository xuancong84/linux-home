#!/usr/bin/env python3

import time, json, argparse, os, sys

import yt_dlp
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By

desired_capabilities = DesiredCapabilities.CHROME
desired_capabilities["goog:loggingPrefs"] = {"performance": "ALL"}

options = webdriver.ChromeOptions()
options.add_argument("--no-sandbox")
options.add_argument("--headless")
options.add_argument('--disable-dev-shm-usage')
options.add_argument("start-maximized")
options.add_argument("--autoplay-policy=no-user-gesture-required")
options.add_argument("disable-infobars")
options.add_argument("--disable-extensions")
options.add_argument("--ignore-certificate-errors")
options.add_argument("--mute-audio")
options.add_argument("--disable-notifications")
options.add_argument("--disable-popup-blocking")
options.add_argument(f'user-agent={desired_capabilities}')


driver = webdriver.Chrome(service = Service(ChromeDriverManager().install()),
                          options = options,
                          desired_capabilities = desired_capabilities)


def get_m3u8_urls(url, wait_time=20):
	driver.get(url)
	driver.execute_script("window.scrollTo(0, 10000)")
	time.sleep(wait_time)
	logs = driver.get_log("performance")
	url_list = []

	for log in logs:
		network_log = json.loads(log["message"])["message"]
		if ("Network.response" in network_log["method"]
				or "Network.request" in network_log["method"]
				or "Network.webSocket" in network_log["method"]):
			if 'request' in network_log["params"]:
				if 'url' in network_log["params"]["request"]:
					if 'm3u8' in network_log["params"]["request"]["url"] or '.mp4' in network_log["params"]["request"]["url"]:
						if "blob" not in network_log["params"]["request"]["url"]:
							if '.m3u8' in network_log["params"]["request"]["url"]:
								url_list.append(network_log["params"]["request"]["url"])

	driver.close()
	return url_list


if __name__ == "__main__":
	parser = argparse.ArgumentParser(usage = '$0 arg1 1>output 2>progress', description = 'this program downloads m3u8 MP4 videos from a video website URL',
	                                 formatter_class = argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('url', help = 'the URL of the video')
	parser.add_argument('--output', '-o', help = 'output file to save to', default = '')
	parser.add_argument('--indices', '-i', help = 'indices of m3u8 files to download, as Python list, e.g., [0,-1], [:-1]', default = '[0]')
	parser.add_argument('--wait-time', '-t', help = 'number of seconds to wait for loading the page', type = int, default = 10)
	# nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt = parser.parse_args()
	globals().update(vars(opt))

	print(f'Loading webpage from {url} ...')
	url_list = get_m3u8_urls(url)
	print(f'Found m3u8 URLs: {url_list}')
	try:
		dl_list = [url_list[i] for i in eval(indices)]
	except:
		dl_list = eval('url_list'+indices)

	if not output:
		output = os.path.basename(url).split('.')[0]+'.mp4'

	for m3u8 in dl_list:
		bn_m3u8 = os.path.basename(m3u8).split('.')[0]+'.mp4'
		yt_dlp.main(['-o', output+bn_m3u8 if len(dl_list)>1 else output, m3u8])
