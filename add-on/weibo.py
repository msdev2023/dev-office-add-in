import json
import logging
import os
import traceback
from datetime import datetime

import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager

formatter = logging.Formatter(
    "[%(asctime)s] %(funcName)s:%(lineno)d %(levelname)s %(message)s"
)
handler = logging.StreamHandler()
handler.setFormatter(formatter)
logger = logging.getLogger(__name__)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

WEIBO_UID = os.environ.get("WEIBO_UID")
WEIBO_COOKIES = os.environ.get("WEIBO_COOKIES")
WEIBO_LATEST_TIMESTAMP = os.environ.get("WEIBO_LATEST_TIMESTAMP")
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
GITHUB_REPOSITORY = os.environ.get("GITHUB_REPOSITORY")


class GitHubAPI:
    def __init__(self, token):
        self.headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        }

    def create_issue(self, title, body):
        url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/issues"
        data = {
            "title": title,
            "body": body,
        }
        resp = requests.post(url, data=json.dumps(data), headers=self.headers)
        logger.info(resp.status_code)

    def get_latest_timestamp(self):
        url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/actions/variables/WEIBO_LATEST_TIMESTAMP"
        resp = requests.get(url, headers=self.headers)
        logger.info(resp.status_code)
        return resp.json()["value"]

    def update_latest_timestamp(self, ts):
        url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/actions/variables/WEIBO_LATEST_TIMESTAMP"
        data = {
            "name": "WEIBO_LATEST_TIMESTAMP",
            "value": str(ts),
        }
        resp = requests.patch(url, data=json.dumps(data), headers=self.headers)
        logger.info(resp.status_code)

    def update_weibo_cookies(self, cookies):
        url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/actions/variables/WEIBO_COOKIES"
        data = {
            "name": "WEIBO_COOKIES",
            "value": json.dumps(cookies),
        }
        resp = requests.patch(url, data=json.dumps(data), headers=self.headers)
        logger.info(resp.status_code)


class HeadlessWeibo:
    def __init__(self):
        options = Options()
        options.add_argument("--headless")
        # options.add_argument("--disable-dev-shm-usage")
        # options.add_argument('--disable-infobars')
        # options.add_argument("--no-sandbox")
        # options.add_argument('--remote-debugging-port=9222')
        self.driver = webdriver.Chrome(
            service=ChromeService(ChromeDriverManager().install()), options=options
        )

        self.session = requests.Session()
        self.session.headers.update(
            {
                "authority": "weibo.com",
                "accept": "application/json, text/plain, */*",
                "accept-language": "zh-CN,zh;q=0.9",
                "client-version": "v2.40.22",
                "sec-ch-ua": '"Google Chrome";v="111", "Not(A:Brand";v="8", "Chromium";v="111"',
                "sec-ch-ua-mobile": "?0",
                "sec-ch-ua-platform": '"macOS"',
                "sec-fetch-dest": "empty",
                "sec-fetch-mode": "cors",
                "sec-fetch-site": "same-origin",
                "server-version": "v2023.04.04.2",
                "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36",
                "referer": "https://weibo.com",
                # "x-requested-with": "XMLHttpRequest",
            }
        )

    def use_cookies(self, cookies):
        self.driver.get("https://weibo.com")
        self.driver.delete_all_cookies()

        for cookie in cookies:
            self.driver.add_cookie(cookie)

    def get_cookies(self):
        self.driver.get("https://weibo.com")
        cookies = self.driver.get_cookies()
        return cookies

    def start_request(self, gh_api, uid, ts=None):
        logger.info(self.session.cookies.items())
        url = f"https://weibo.com/ajax/statuses/mymblog?uid={uid}&page=1"
        self.session.headers.update(
            {
                "referer": f"https://weibo.com/u/{uid}",
                "x-requested-with": "XMLHttpRequest",
            }
        )
        resp = self.session.get(url)
        logger.info(resp.status_code)
        logger.info(resp.content)
        data = resp.json()
        tweets = data["data"]["list"]

        latest_timestamp = None
        for tweet in tweets:
            try:
                content, created_at = self.parse_tweet(uid, tweet)
            except:
                logger.error(traceback.print_exc())
                continue

            if ts and created_at <= ts:
                break

            if not content:
                continue

            try:
                title = content.split("\n")[0][:60]
                gh_api.create_issue(title, content)
            except:
                logger.error(traceback.print_exc())
                continue

            if latest_timestamp is None or latest_timestamp < created_at:
                latest_timestamp = created_at

        return latest_timestamp

    @staticmethod
    def parse_time(s):
        """
        Thu Apr 06 12:31:14 +0800 2023 => 1680755474
        """
        return int(datetime.strptime(s, "%a %b %d %H:%M:%S %z %Y").timestamp())

    def parse_tweet(self, uid, tweet):
        created_at = self.parse_time(tweet["created_at"])

        if "repost_type" in tweet:
            return None, created_at

        mblogid = tweet["mblogid"]
        content = tweet["text_raw"]
        if "continue_tag" in tweet and tweet["isLongText"]:
            try:
                long_url = f"https://weibo.com/ajax/statuses/longtext?id={mblogid}"
                content = self.retrieve_long_tweet(long_url)
            except:
                logger.error(traceback.print_exc())

        content = content.replace("\u200b", "")
        pic_urls = [
            f"![](https://wx1.sinaimg.cn/orj960/{pic_id})"
            for pic_id in tweet.get("pic_ids", [])
        ]
        tweet_url = f"https://weibo.com/{uid}/{mblogid}"
        content += "\n" + "\n".join(pic_urls) + "\n\n" + tweet_url
        return content, created_at

    def retrieve_long_tweet(self, url):
        resp = self.session.get(url)
        logger.info(resp.status_code)
        data = resp.json()
        return data["data"]["longTextContent"]


def main():
    headless = HeadlessWeibo()
    headless.use_cookies(json.loads(WEIBO_COOKIES))
    new_cookies = headless.get_cookies()

    gh_api = GitHubAPI(token=GITHUB_TOKEN)
    gh_api.update_weibo_cookies(new_cookies)

    for cookie in new_cookies:
        headless.session.cookies.set(cookie["name"], cookie["value"])

    new_ts = headless.start_request(gh_api, WEIBO_UID, ts=int(WEIBO_LATEST_TIMESTAMP))
    gh_api.update_latest_timestamp(new_ts)


if __name__ == "__main__":
    try:
        main()
    except:
        logger.error(traceback.print_exc())
