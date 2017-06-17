# WatchRealmSync
Implementation example of synchronizing Realm DB between watchOS and iOS.  
Since it has stabilized, I will post the second version.  
Please see Demo2.gif.

## Features
* Realize DB sync using simple Realm programming.
* By changing the template, you can use it generally.
* It is not necessary to be aware of the sync mechanism whenever possible.
* Offline correspondence.

#### No good
* Only flat and single, Realm DB can be sync.
* "List" type can not be transferred. Attention required for "Int" type.
* Slow (watchOS table update and digest/hash function).
* Synchronization may be impossible (when transfer file can not be read). This will force sync.
* In case of UI high load (watchOS side), occasionally ABEND with "exit 0".
* In some cases, I'm using a hard code (e.g. "Lap.self").

For the above reasons, this app is "sample".

#### To Do
* "WatchIPhoneConnect" observer patternization.
* WatchOS side background processing.
* IOS background launch.
* Error countermeasure (retry and timeout).
* Confirm the boot procedure.

## Demo project

#### Requirements and development env
* Xcode 8.3.3
* iOS 10.3
* watchOS 3.2

#### Make
1. $ cd WatchRealmSync-master
2. $ pod install
3. Open Xcode “WatchRealmSync.xcworkspace”
4. TARGET -> "WatchRealmSync" -> “General tab”
 * Identify -> Build Identifier: "com.`YourCompany`.WatchRealmSync..." change to your_company identifier.
 * Singing -> Team : "`None`" set your development team.
5. Change TARGET -> "WatchRealmSyncWatchApp", "WatchRealmSyncWatchApp Extension", and same OP item 4.
6. Run

#### Operation : iOS
* tap line : select item.
* trash : Delete selected items.
* Num button : Randomize selected items. Numbers are displayed item count / selected count / total count.
* \+ : Make an item.
* Make10 : Make 10 items. 1/3 is selected.
* DelAll : Delete all.
* Reload : Force sync.

##### Operation : watchOS
* tap line : select item.
* X : Delete selected items.
* Num button : Randomize selected items. Numbers are displayed item count.
* \+ : Make an item.
* Deep Press + "Sync all" : Force sync.
* Deep Press + "Add 10" : Make 10 items. 1/3 is selected.
* Deep Press + "Delete all" : Delete all.

## License
Distributed under the MIT License.

## Author
If you wish to contact me, email at: agepro60@gmail.com
