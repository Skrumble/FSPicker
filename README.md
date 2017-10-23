# FSPicker for iOS (SKRUMBLE)

this is a forked from : https://github.com/filestack/FSPicker

The Skrumble App is using this library to send attachment file to a chat.

We decided to make a fork because the version 1.1.8 doesn't work properly on our app and many problem needed to be fixed quicky

Here is the list of the change we did:
- Album photo are displayed in reverse order
- Fail to upload delegate are called only one time
- Open properly Camera or Album after the user accept Permission access (camera or documents)
- Log out from Drive account bring the user back to the main screem
- Able to Upload Media from cloud (allow network access)
- Config option for "Should Upload"
- Fixed Source List/Collection get hide by the navigation bar (define constraint instead of insets)
- Fixed Thread sync issue when upload multiple file
- Prevent FSUpload Deallocation right after finish network task, delegate wasn't called properly





