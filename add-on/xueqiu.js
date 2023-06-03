/**
  * Gets the stock price at the end of month.
  * @customfunction
  * @param {string} symbol Xueqiu stock symbol
  * @param {number} year Year
  * @param {number} month Month
  * @return {number} The stock price at the end of month
  */
async function getStockPrice(symbol, year, month) {
  try {
    const begin = (new Date()).getTime() + 86400000;
    const headers = {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'en-US,en;q=0.9',
      'Host': 'stock.xueqiu.com',
      'Origin': 'https://xueqiu.com',
      'Referer': 'https://xueqiu.com/S/'+symbol,
      'sec-ch-ua': '"Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"macOS"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site'
    };
    const url = "https://stock.xueqiu.com/v5/stock/chart/kline.json?symbol="+symbol+"&begin="+begin+"&period=month&type=before&count=-284&indicator=kline,pe,pb,ps,pcf,market_capital,agt,ggt,balance"
    const response = await fetch(url, {headers: headers});
    if (!response.ok) {
      throw new Error(response.statusText)
    }
    const json = await response.json();
    const items = json["data"]["item"];
    for (let index = items.length - 1; index >= 0; index--){
      let date = new Date(items[index][0]);
      if (date.getFullYear() === year && date.getMonth() === month - 1) {
        return items[index][5];
      }
    }
  }
  catch (error) {
    return error;
  }
}
