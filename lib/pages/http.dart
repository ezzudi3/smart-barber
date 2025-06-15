import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> createPaymentLink() async {
  // Toyyibpay API URL
  final url = 'https://www.toyyibpay.com/index.php/api/createBill';

  // Toyyibpay API credentials (use the Merchant ID and API key you got from Toyyibpay)
  final merchantId = 'your_merchant_id';
  final apiKey = 'your_api_key';

  final headers = {
    'Content-Type': 'application/json',
  };

  final body = json.encode({
    "merchantCode": merchantId,
    "billName": "Sample Payment", // Payment name
    "billDescription": "Description of the product/service",
    "billPriceSetting": 2, // 1 for fixed price, 2 for dynamic price
    "billCurrency": "MYR", // Currency
    "billReturnUrl": "https://yourwebsite.com/return", // Redirect URL after payment
    "billCallbackUrl": "https://yourwebsite.com/callback", // Notification URL after payment
    "billExternalReferenceNo": "ORDER12345", // Order reference
    "billPhone": "customer_phone_number", // Customer phone
    "billEmail": "customer_email" // Customer email
  });

  try {
    final response = await http.post(Uri.parse(url), headers: headers, body: body);

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'OK') {
        print('Payment link created successfully');
        print('Payment URL: ${responseData['payment_url']}');
        // Navigate the user to the payment URL
        // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentPage(paymentUrl: responseData['payment_url'])));
      } else {
        print('Error creating payment link: ${responseData['message']}');
      }
    } else {
      print('Failed to connect to Toyyibpay API');
    }
  } catch (e) {
    print('Error: $e');
  }
}
