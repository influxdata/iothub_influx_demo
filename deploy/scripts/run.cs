#r "Newtonsoft.Json"

using System;
using System.Text;
using System.Net.Http;
using Newtonsoft.Json;


public static async Task Run(string myIoTHubMessage, ILogger log)
{
    var influxIp =  Environment.GetEnvironmentVariable("INFLUX_HOST", EnvironmentVariableTarget.Process);
    log.LogInformation($"Using host: {influxIp}");

    MetricsList all = JsonConvert.DeserializeObject<MetricsList>(myIoTHubMessage);

    using(var client = new HttpClient())
    {
        client.BaseAddress = new Uri($"http://{influxIp}:8086/");
        HttpContent c = new StringContent(all.ToString(), Encoding.UTF8, "text/plain");  
        log.LogInformation(all.ToString());          
        var result = await client.PostAsync("write?db=opcdata&precision=s",c);
        string resultContent = await result.Content.ReadAsStringAsync();
        log.LogInformation(resultContent);
    }
}

public class metric {
    public Dictionary<string, object> fields;
    public string name;
    public Dictionary<string, string> tags;
    public long timestamp;

    public string ToString() {
        string ts = "";
        foreach(var item in tags){
            var k = item.Key;
            var v = item.Value;

            if (!String.IsNullOrWhiteSpace(ts)) {
                ts = string.Format("{0},", ts);
            }

            ts = string.Format("{0}{1}={2}", ts, k, v);
        }

        string fs = "";

        foreach(var item in fields){
            var k = item.Key;
            var v = item.Value;

            if (!String.IsNullOrWhiteSpace(fs)) {
                fs = string.Format("{0},", fs);
            }

            fs = string.Format("{0}{1}={2}", fs, k, v);
        }

        string template = "{0},{1} {2} {3}";
        string output = string.Format(template, name, ts, fs, timestamp);
        return output;
    }

}

public class MetricsList {
    public List<metric> metrics;

    public string ToString() {
            
        string output = "";
        
        foreach (metric m in metrics) {
            string toAdd = m.ToString();
            output = string.Format("{0}\n{1}", output, toAdd);
        }

        return output;
    }
}

