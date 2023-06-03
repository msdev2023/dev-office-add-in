from datetime import datetime, timezone, timedelta

import aiohttp
import asyncio

CST = timezone(timedelta(hours=8))


async def request_kline(session, symbol, period="month", k="before"):
    headers = {
        "Origin": "https://xueqiu.com",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "sec-ch-ua": '" Not A;Brand";v="99", "Chromium";v="96", "Google Chrome";v="96"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
    }
    referrer = f"https://xueqiu.com/S/{symbol}"
    await session.get(referrer, headers=headers)

    url = "https://stock.xueqiu.com/v5/stock/chart/kline.json"
    params = {
        "symbol": symbol,
        "period": period,
        "begin": int((datetime.now().timestamp() + 24 * 3600) * 1000),
        "count": -284,
        "type": k or "normal",
        "indicator": "kline,pe,pb,ps,pcf,market_capital,agt,ggt,balance",
    }
    headers.update(
        {
            "Accept": "application/json, text/plain, */*",
            "Referer": referrer,
        }
    )

    async with session.get(url, params=params, headers=headers) as resp:
        data = await resp.json()
        # data = data['data']['item']
        # print(data)
        return data


class Loss(dict):
    def __setitem__(self, key, value):
        super().__setitem__(key, value)

        if key == "low":
            self["loss"] = max(self.get("loss", 0), 1 - self["low"] / self["high"])

    def __setattr__(self, key, value):
        return self.__setitem__(key, value)

    def __getattr__(self, key):
        return self.__getitem__(key)


def parse_kline(items: list[dict]):
    if not items:
        return

    max_loss = close = None

    for item in items:
        high, low, close = item[3], item[4], item[5]

        # history
        if max_loss is None:
            max_loss = Loss(high=high, low=low)

        if low < max_loss.low:
            max_loss.low = low

        if high > max_loss.high:
            max_loss.high = high
            max_loss.low = low

    return max_loss, close


async def worker(session, symbol, semaphore=None):
    try:
        if semaphore is None:
            data = await request_kline(session, symbol)
        else:
            async with semaphore:
                data = await request_kline(session, symbol)

        return parse_kline(data["data"]["item"])
    except:
        return None


async def runner():
    codes = [
        {"code": "000300", "symbol": "SH000300", "name": "沪深 300"},
        {"code": "000905", "symbol": "SH000905", "name": "中证 500"},
        {"code": "399006", "symbol": "SZ399006", "name": "创业板"},
        {"code": "HKHSI", "symbol": "HKHSI", "name": "恒生指数"},
    ]
    tasks = []
    session = aiohttp.ClientSession()
    semaphore = asyncio.Semaphore(5)
    for code in codes:
        task = asyncio.create_task(worker(session, code["symbol"], semaphore))
        tasks.append(task)

    await asyncio.gather(*tasks)
    await session.close()

    print(
        f"{'Code':<8}\t{'Highest':>10}\t{'HistoryMaxLoss':>16}\t{'Current':>10}\t{'Current2MaxLoss':>19}\t{'Current2Loss70':>19}\t{'Current2Loss80':>19}"
    )
    print(
        f"{'-' * 8}\t{'-' * 10}\t{'-' * 16}\t{'-' * 10}\t{'-' * 19}\t{'-' * 19}\t{'-' * 19}"
    )

    for index, task in enumerate(tasks):
        name = codes[index]["name"]
        data = task.result()
        if not data:
            print(f"{name:<8}")
        else:
            max_loss, close = data

            v70 = max_loss.high * 0.3
            v80 = max_loss.high * 0.2
            vmax = max_loss.high * (1 - max_loss.loss)

            p70 = 1 - v70 / close
            p80 = 1 - v80 / close
            pmax = 1 - vmax / close

            s70 = f"{v70:>9.3f} ({p70 * 100:>6.2f}%)"
            s80 = f"{v80:>9.3f} ({p80 * 100:>6.2f}%)"
            smax = f"{vmax:>9.3f} ({pmax * 100:>6.2f}%)"
            sloss = f"{max_loss.loss * 100:>15.2f}%"

            print(f"{name:<8}\t{max_loss.high:>10.3f}\t{sloss}\t{close:>10.3f}\t{smax}\t{s70}\t{s80}")


def main():
    loop = asyncio.get_event_loop()
    loop.run_until_complete(runner())


if __name__ == "__main__":
    main()
