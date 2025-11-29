using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NiftyOptionChainService
{
    public class DhanApiSettings
    {
        public string optionchain { get; set; } = string.Empty;
        public string expirylist { get; set; } = string.Empty;
        public string AccessToken { get; set; } = string.Empty;
        public string ClientId { get; set; } = string.Empty; 
        public string nextExpiry { get; set; } = string.Empty;
        public bool IsMarketOpen { get; set; } = false;
        public bool isFetchedExpiryDetails { get; set; } = false;
        public bool isFetchMarketStatus { get; set; } = false;


    }
}
