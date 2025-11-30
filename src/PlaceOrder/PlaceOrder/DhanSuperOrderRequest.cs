using System;
using System.Collections.Generic;
using System.Text;

namespace PlaceOrder
{
    public class DhanSuperOrderRequest
    {
        public string dhanClientId { get; set; }
        public string correlationId { get; set; }
        public string transactionType { get; set; }
        public string exchangeSegment { get; set; }
        public string productType { get; set; }
        public string orderType { get; set; }
        public string securityId { get; set; }
        public int quantity { get; set; }
        public decimal price { get; set; }
        public decimal stopLossPrice { get; set; }
        public decimal trailingJump { get; set; }   // MAIN FIELD
    }
}
