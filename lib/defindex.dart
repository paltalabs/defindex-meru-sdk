library defindex;

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:defindex/custom_soroban_server.dart';
import 'package:defindex/contants.dart';

enum SorobanNetwork {
  PUBLIC,
  TESTNET,
}

class DefiIndex {
  String sorobanRPCUrl;
  late CustomSorobanServer sorobanServer;
  late final StellarSDK sdk;
  late final SorobanNetwork network;

  DefiIndex({
    required this.sorobanRPCUrl,
    this.network = SorobanNetwork.TESTNET,
  }) {
    sorobanServer = CustomSorobanServer(sorobanRPCUrl);
    sdk = network == SorobanNetwork.TESTNET
        ? StellarSDK.TESTNET
        : StellarSDK.PUBLIC;
  }

  // poll until success or error
  Future<GetTransactionResponse> pollStatus(String transactionId) async {
    var status = GetTransactionResponse.STATUS_NOT_FOUND;
    GetTransactionResponse? transactionResponse;

    while (status == GetTransactionResponse.STATUS_NOT_FOUND) {
      await Future.delayed(const Duration(seconds: 5), () {});
      transactionResponse = await sorobanServer.getTransaction(transactionId);
      assert(transactionResponse.error == null);
      status = transactionResponse.status!;
      if (status == GetTransactionResponse.STATUS_FAILED) {
        assert(transactionResponse.resultXdr != null);
        assert(false);
      } else if (status == GetTransactionResponse.STATUS_SUCCESS) {
        assert(transactionResponse.resultXdr != null);
      }
    }
    return transactionResponse!;
  }

  Future<String?> deposit(String accountId, double amount,
      Future<String> Function(String) signer) async {
    sorobanServer.enableLogging = true;

    GetHealthResponse healthResponse = await sorobanServer.getHealth();

    if (GetHealthResponse.HEALTHY == healthResponse.status) {
      AccountResponse account = await sdk.accounts.account(accountId);
      // Name of the function to be invoked
      String functionName = "deposit";

      // Determine the number of digits to multiply to achieve at least 7 digits in the decimal place
      int factor = 10000000;

      // Multiply the value by the factor and convert to int
      BigInt bigIntValue = BigInt.from(amount * factor);

      int transformedValue = bigIntValue.toInt();

      // Prepare the argument (Symbol)
      XdrSCVal arg1 = XdrSCVal.forI128(
          XdrInt128Parts(XdrInt64(0), XdrUint64(transformedValue)));

      XdrSCVal arg2 = XdrSCVal.forAddress(XdrSCAddress.forAccountId(accountId));

      String contractId = network == SorobanNetwork.PUBLIC
          ? DEFINDEX_CONTRACT_ID_MAINNET
          : DEFINDEX_CONTRACT_ID_TESTNET;

      // Prepare the "invoke" operation
      InvokeContractHostFunction hostFunction = InvokeContractHostFunction(
          contractId, functionName,
          arguments: [arg1, arg2]);

      InvokeHostFunctionOperation operation =
          InvokeHostFuncOpBuilder(hostFunction).build();

      Transaction transaction =
          TransactionBuilder(account).addOperation(operation).build();

      var request = SimulateTransactionRequest(transaction);

      SimulateTransactionResponse simulateResponse =
          await sorobanServer.simulateTransaction(request);

      // simulateResponse.transactionData!.resourceFee =
      //     XdrInt64(((simulateResponse.minResourceFee ?? 0) * 120) ~/ 100);
      // simulateResponse.minResourceFee =
      //     ((simulateResponse.minResourceFee ?? 0) * 120) ~/ 100;

      // set transaction data, add resource fee and sign transaction
      transaction.sorobanTransactionData = simulateResponse.transactionData;
      transaction.addResourceFee(simulateResponse.minResourceFee!);
      transaction.setSorobanAuth(simulateResponse.sorobanAuth);

      String transactionString =
          transaction.toEnvelopeXdr().toEnvelopeXdrBase64();

      String transactionSigned = await signer(transactionString);

      SendTransactionResponse sendResponse =
          await sorobanServer.sendRawTransaction(transactionSigned);

      assert(!sendResponse.isErrorResponse);

      assert(sendResponse.status != SendTransactionResponse.STATUS_ERROR);

      GetTransactionResponse statusResponse =
          await pollStatus(sendResponse.hash!);

      String status = statusResponse.status!;
      assert(status == GetTransactionResponse.STATUS_SUCCESS);

      return sendResponse.hash;
    }

    return null;
  }

  Future<String?> withdraw(
      String accountId, Future<String> Function(String) signer) async {
    sorobanServer.enableLogging = true;

    GetHealthResponse healthResponse = await sorobanServer.getHealth();

    if (GetHealthResponse.HEALTHY == healthResponse.status) {
      AccountResponse account = await sdk.accounts.account(accountId);
      // Name of the function to be invoked
      String functionName = "widthdraw";

      XdrSCVal arg1 = XdrSCVal.forAddress(XdrSCAddress.forAccountId(accountId));

      String contractId = network == SorobanNetwork.PUBLIC
          ? DEFINDEX_CONTRACT_ID_MAINNET
          : DEFINDEX_CONTRACT_ID_TESTNET;

      // Prepare the "invoke" operation
      InvokeContractHostFunction hostFunction = InvokeContractHostFunction(
          contractId, functionName,
          arguments: [arg1]);

      InvokeHostFunctionOperation operation =
          InvokeHostFuncOpBuilder(hostFunction).build();

      Transaction transaction =
          TransactionBuilder(account).addOperation(operation).build();

      var request = SimulateTransactionRequest(transaction);

      SimulateTransactionResponse simulateResponse =
          await sorobanServer.simulateTransaction(request);

      transaction.sorobanTransactionData = simulateResponse.transactionData;
      transaction.addResourceFee(simulateResponse.minResourceFee!);
      transaction.setSorobanAuth(simulateResponse.sorobanAuth);

      String transactionString =
          transaction.toEnvelopeXdr().toEnvelopeXdrBase64();

      String transactionSigned = await signer(transactionString);

      SendTransactionResponse sendResponse =
          await sorobanServer.sendRawTransaction(transactionSigned);

      assert(!sendResponse.isErrorResponse);

      assert(sendResponse.status != SendTransactionResponse.STATUS_ERROR);

      GetTransactionResponse statusResponse =
          await pollStatus(sendResponse.hash!);

      String status = statusResponse.status!;
      assert(status == GetTransactionResponse.STATUS_SUCCESS);

      return sendResponse.hash;
    }

    return null;
  }

  Future<double?> totalBalance(
      String accountId, Future<String> Function(String) signer) async {
    sorobanServer.enableLogging = true;

    GetHealthResponse healthResponse = await sorobanServer.getHealth();

    if (GetHealthResponse.HEALTHY == healthResponse.status) {
      AccountResponse account = await sdk.accounts.account(accountId);
      // Name of the function to be invoked
      String functionName = "balance";

      XdrSCVal arg1 = XdrSCVal.forAddress(XdrSCAddress.forAccountId(accountId));

      String contractId = network == SorobanNetwork.PUBLIC
          ? DEFINDEX_CONTRACT_ID_MAINNET
          : DEFINDEX_CONTRACT_ID_TESTNET;

      // Prepare the "invoke" operation
      InvokeContractHostFunction hostFunction = InvokeContractHostFunction(
          contractId, functionName,
          arguments: [arg1]);

      InvokeHostFunctionOperation operation =
          InvokeHostFuncOpBuilder(hostFunction).build();

      Transaction transaction =
          TransactionBuilder(account).addOperation(operation).build();

      var request = SimulateTransactionRequest(transaction);

      SimulateTransactionResponse simulateResponse =
          await sorobanServer.simulateTransaction(request);

      transaction.sorobanTransactionData = simulateResponse.transactionData;
      transaction.addResourceFee(simulateResponse.minResourceFee!);
      transaction.setSorobanAuth(simulateResponse.sorobanAuth);

      String transactionString =
          transaction.toEnvelopeXdr().toEnvelopeXdrBase64();

      String transactionSigned = await signer(transactionString);

      SendTransactionResponse sendResponse =
          await sorobanServer.sendRawTransaction(transactionSigned);

      assert(!sendResponse.isErrorResponse);

      assert(sendResponse.status != SendTransactionResponse.STATUS_ERROR);

      GetTransactionResponse transactionResponse =
          await pollStatus(sendResponse.hash!);

      String status = transactionResponse.status!;
      assert(status == GetTransactionResponse.STATUS_SUCCESS);

      XdrSCVal resVal = transactionResponse.getResultValue()!;

      List<XdrSCVal>? vec = resVal.vec;

      if (vec != null) {
        if (vec[0].i128?.lo.uint64 != null) {
          return (vec[0].i128?.lo.uint64 ?? 0) / 10000000;
        }
      }

      return 0;
    }

    return null;
  }
}
