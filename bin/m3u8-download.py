#!/usr/bin/env python3

import time, argparse, os, sys, re
import yt_dlp

from seleniumwire import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.common.by import By
from collections import defaultdict

driver = None

def create_chrome():
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
	driver = webdriver.Chrome(service = Service(ChromeDriverManager().install()), options = options)
	return driver

def create_firefox():
	desired_capabilities = DesiredCapabilities.FIREFOX
	desired_capabilities["goog:loggingPrefs"] = {"performance": "ALL"}
	options = FirefoxOptions()
	options.add_argument("--headless")
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
	driver = webdriver.Firefox(options=options)
	return driver

def find_closest_quote(S):
	p1 = S.find("'")
	p2 = S.find('"')
	p1, p2 = [(v if v>=0 else 999999999) for v in [p1,p2]]
	return (p1, "'") if p1<p2 else (p2, '"')

def extract_in_quotes(S, posi):
	offset, quote = find_closest_quote(S[posi:])
	if offset>len(S):
		return ''
	p2 = posi+offset
	p1 = S[:posi].rfind(quote)+1
	return S[p1:p2] if p1>0 else ''

def get_m3u8_urls(url, wait_time=20):
	global driver
	driver.get(url)
	driver.execute_script("window.scrollTo(0, 10000)")
	time.sleep(wait_time)

	url_list = [r.url for r in driver.requests if r.url.endswith('.m3u8')] + ['']

	for m in re.finditer('\.m3u8', driver.page_source):
		url = extract_in_quotes(driver.page_source , m.start())
		if url:
			url_list += [url]

	try:
		p = re.search('[^/]/[^/]', driver.current_url).start()+1
		prefix = driver.current_url[:p]
		url_list = [(prefix+u if u.startswith('/') else u) for u in url_list]
	except:
		pass

	driver.close()

	return url_list


def get_platform():
	if sys.platform == "darwin":
		return "osx"
	elif sys.platform.startswith("linux"):
		return "linux"
	elif sys.platform.startswith("win"):
		return "windows"
	else:
		return "unknown"


def get_default_browser_cookie(platform):
	platform = 'linux' if platform=='raspberry_pi' else platform
	def_cookie_loc = defaultdict(lambda:defaultdict(lambda:''))
	def_cookie_loc['linux']['firefox'] = '$HOME/.mozilla/firefox/'
	def_cookie_loc['linux']['chrome'] = '$HOME/.config/google-chrome/'
	def_cookie_loc['linux']['chromium'] = '$HOME/.config/chromium/'
	def_cookie_loc['windows']['firefox'] = '%APPDATA%\\Mozilla\\Firefox\\Profiles'
	def_cookie_loc['windows']['chrome'] = '%LOCALAPPDATA%\\Google\\Chrome\\User Data\\Default\\Network'
	def_cookie_loc['windows']['edge'] = '%LOCALAPPDATA%\\Microsoft\\Edge\\User Data\\Default\\Network'
	def_cookie_loc['windows']['ie'] = '%USERPROFILE%\\AppData\\Roaming\\Microsoft\\Windows\\Cookies'
	def_cookie_loc['osx']['firefox'] = '$HOME/Library/Application Support/Firefox/Profiles/'
	def_cookie_loc['osx']['chrome'] = '$HOME/Library/Application Support/Google/Chrome/'
	def_cookie_loc['osx']['safari'] = '$HOME/Library/Cookies/'
	try:
		if platform == 'windows':
			browsers = ['firefox', 'chrome', 'ie', 'edge']
			from winreg import OpenKey, HKEY_CURRENT_USER, QueryValueEx
			with OpenKey(HKEY_CURRENT_USER, r"Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\http\\UserChoice") as key:
				browser = QueryValueEx(key, 'Progid')[0].lower()
	except:
		return ''
	ret = os.path.expandvars(def_cookie_loc[platform]['chrome'])
	return f'chrome:{ret}' if ret else ''

if __name__ == "__main__":
	parser = argparse.ArgumentParser(usage = '$0 arg1 1>output 2>progress', description = 'this program downloads m3u8 MP4 videos from a video website URL',
	                                 formatter_class = argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('url', help = 'the URL of the video')
	parser.add_argument('--browser', '-b', help = 'browser driver', choices=['firefox', 'chrome'], default = 'firefox')
	parser.add_argument('--list-only', '-l', help = 'list the URLs of *.m3u8', action='store_true')
	parser.add_argument('--output', '-o', help = 'output file to save to', default = '')
	parser.add_argument('--indices', '-i', help = 'index/indices of m3u8 files to download, as Python list, e.g., 0, -1, [0,-1], [:-1]', default = '0')
	parser.add_argument('--wait-time', '-t', help = 'number of seconds to wait for loading the page', type = int, default = 3)
	parser.add_argument('-c', "--browser-cookies", default = "auto",
		help = "YouTube downloader can use browser cookies from the specified path (see the --cookies-from-browser option of yt-dlp), it can also be auto (default): automatically determine based on OS; none: do not use any browser cookies",
	)
	# nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt = parser.parse_args()
	globals().update(vars(opt))

	driver = create_firefox() if browser=='firefox' else create_chrome()

	# Set browser cookies location for YouTube downloader
	if opt.browser_cookies.lower() == 'none':
		opt.cookies_opt = []
	elif opt.browser_cookies.lower() == 'auto':
		path = get_default_browser_cookie(get_platform())
		opt.cookies_opt = ['--cookies-from-browser', path] if path else []
	else:
		opt.cookies_opt = ['--cookies-from-browser', opt.browser_cookies]

	print(f'Loading webpage from {url} ...')
	url_list = get_m3u8_urls(url)
	print('Found m3u8 URLs: \n' + '\n'.join(url_list))

	if list_only:
		sys.exit(0)

	try:
		dl_list = [url_list[int(indices)]]
	except:
		try:
			dl_list = [url_list[i] for i in eval(indices)]
		except:
			dl_list = eval('url_list'+indices)

	if not output:
		output = os.path.basename(url).split('.')[0]+'.mp4'

	for m3u8 in dl_list:
		bn_m3u8 = os.path.basename(m3u8).split('.')[0]+'.mp4'
		yt_dlp.main(['--fixup', 'force', '--remux-video', 'mp4', '-o', output+bn_m3u8 if len(dl_list)>1 else output, m3u8])
