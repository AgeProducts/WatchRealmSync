# WatchRealmSync
Sample implementation to synchronize Realm table (DB) between watchOS and iOS.  
Slightly stable so I will post the second version.  
Please see Demo.gif.

## Features
* Realize Realm DB sync with normal Realm programming.
* Offline compatible.

## Demo project

#### Requirements
* Xcode 8.3.2
* iOS 10.3.
* watchOS 3.2

#### Make
1. $ cd WatchRealmSync\ master
2. $ pod install
3. Open Xcode “WatchRealmSync.xcworkspace”
4. TARGET -> "WatchRealmSync" -> “General tab”
 * Identify -> Build Identifier: `"com.YourCompany.WatchRealmSync.."` change to your_company identifier.
 * Singing -> Team : `"None"` set your development team.
5. Change TARGET -> "WatchRealmSyncWatchApp", "WatchRealmSyncWatchApp Extension", and same OP item 4.
6. Run

#### Operation (iOS)
* tap line : select item.
* \+ : Make an item.
* trash icon: Delete selected items.
* compose icon: Randomize selected items.
* Make10 : Make 10 items. 1/3 is selected.
* DelAll : Delete all.
* Reload : Refresh all items.

##### Operation (watchOS)
* tap line : select item.
* \+ : Make an item.
* mod : Randomize selected items.
* X : Delete selected items.
* longPress + "Sync" : Refresh all items.

## Limitations and Known issues
* In case of UI high load (Watch side), occasionally ABEND with "exit 0".
* Display update of WKInterfaceTable is extremely slow. When updating display items in sorting order (e.g. Demo), 20 items or less is practical. In the case of no rearrangement (addition, deletion, content change) it is OK even for about 100 items.
* Realm DB size and number of items are not limited.
* The strictness of the millisecond level can not be guaranteed.
* Multiple Watch Not Supported. Also, although background functions are implemented, verification is incomplete..

For the above reasons, this app is "sample".

## Modify demo app
### Lap.swift
1. Item identifier ~ youWrote is prohibited from changing.
2. Add, modify and delete items freely below the item "select".
3. For added items to be sync, please modify the code of function lapItemCopy (copy) and lapItemComp (compare).

### WatchRealmSync and WatchRealmSyncWatchApp Extension
1. It is based on normal (iOS/watchOS) Realm app programming.
2. When using Realm notification (addNotificationBlock), register token in sync mechanism. See "InterfaceController.swift".
 * Token acquisition : `notificationToken = laps.addNotificationBlock {`
 * Token registration : `Common2.sharedInstance.realmTokens.append(notificationToken)`
 * If you do not register token, you will be notified twice for a single write. Performance will not be a problem with iOS (e.g. ViewController.swift). I feel bad, but...

## License
Distributed under the MIT License.

## Author
If you wish to contact me, email at: agepro60@gmail.com
