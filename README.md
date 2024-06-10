# Test IT TMS Adapter for Flutter

## Getting Started

### Installation

With Dart:

```bash
dart pub add adapters_flutter
```

With Flutter:

```bash
flutter pub add adapters_flutter
```

## Usage

### Configuration

| Description                                                                                                                                                                                                                                                                                                                                                                            | File property              | Environment variable              |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------|-----------------------------------|
| Location of the TMS instance                                                                                                                                                                                                                                                                                                                                                           | url                        | TMS_URL                           |
| API secret key [How to getting API secret key?](https://github.com/testit-tms/.github/tree/main/configuration#privatetoken)                                                                                                                                                                                                                                                            | privateToken               | TMS_PRIVATE_TOKEN                 |
| ID of project in TMS instance [How to getting project ID?](https://github.com/testit-tms/.github/tree/main/configuration#projectid)                                                                                                                                                                                                                                                    | projectId                  | TMS_PROJECT_ID                    |
| ID of configuration in TMS instance [How to getting configuration ID?](https://github.com/testit-tms/.github/tree/main/configuration#configurationid)                                                                                                                                                                                                                                  | configurationId            | TMS_CONFIGURATION_ID              |
| ID of the created test run in TMS instance.                                                                                                                                                                                                                                                                                                                                            | testRunId                  | TMS_TEST_RUN_ID                   |
| Adapter mode. Default value - 0. The adapter supports following modes:<br/>0 - in this mode, the adapter filters tests by test run ID and configuration ID, and sends the results to the test run<br/>1 - in this mode, the adapter sends all results to the test run without filtering<br/>2 - in this mode, the adapter creates a new test run and sends results to the new test run | adapterMode                | TMS_ADAPTER_MODE                  | tmsAdapterMode                |
| It enables/disables certificate validation (**It's optional**). Default value - true                                                                                                                                                                                                                                                                                                   | certValidation             | TMS_CERT_VALIDATION               |
| Mode of automatic creation test cases (**It's optional**). Default value - false. The adapter supports following modes:<br/>true - in this mode, the adapter will create a test case linked to the created autotest (not to the updated autotest)<br/>false - in this mode, the adapter will not create a test case                                                                    | automaticCreationTestCases | TMS_AUTOMATIC_CREATION_TEST_CASES |

#### File

Create **tms.config.json** file in the project directory:

```json
{
  "url": "URL",
  "privateToken": "USER_PRIVATE_TOKEN",
  "projectId": "PROJECT_ID",
  "configurationId": "CONFIGURATION_ID",
  "testRunId": "TEST_RUN_ID",
  "automaticCreationTestCases": false,
  "certValidation": true,
  "adapterMode": 0
}
```

### Metadata of autotest

Use metadata to specify information about autotest.

Description of metadata:

* `workItemsIds` - a method that links autotests with manual tests. Receives the array of manual
  tests' IDs
* `externalId` - unique internal autotest ID (used in Test IT)
* `title` - autotest name specified in the autotest card. If not specified, the name from the
  displayName method is used
* `description` - autotest description specified in the autotest card
* `labels` - tags listed in the autotest card
* `links` - links listed in the autotest card
* `step` - the designation of the step

Description of methods:

* `tms.AddLinks` - add links to the autotest result.
* `tms.AddAttachments` - add attachments to the autotest result.
* `tms.AddAtachmentsFromString` - add attachments from string to the autotest result.
* `tms.AddMessage` - add message to the autotest result.

### Examples

#### Simple test

```dart
import 'package:adapters_flutter/adapters_flutter.dart';

void main() async {
  await testAsync('calculate', externalId: '1234', workItemsIds: ['45712'],
          () async {
        await stepAsync('example step title', () async {
          await getConfigAsync();
          await getConfigAsync();
        });

        await stepAsync('failed step', () async {
          throw Exception('example exception');
        });
      });
}
```

## Contributing

You can help to develop the project. Any contributions are **greatly appreciated**.

* If you have suggestions for adding or removing projects, feel free
  to [open an issue](https://github.com/testit-tms/adapters-go/issues/new) to discuss it, or create
  a direct pull
  request after you edit the *README.md* file with necessary changes.
* Make sure to check your spelling and grammar.
* Create individual PR for each suggestion.
* Read the [Code Of Conduct](https://github.com/testit-tms/adapters-go/blob/main/CODE_OF_CONDUCT.md)
  before posting
  your first idea as well.

## License

Distributed under the Apache-2.0 License.
See [LICENSE](https://github.com/testit-tms/adapters-go/blob/main/LICENSE.md) for more information.
