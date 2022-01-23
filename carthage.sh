xcodebuild archive \
 -scheme GRDBiOS \
 -project GRDB.xcodeproj \
 -archivePath ~/Desktop/GRDB-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 SKIP_INSTALL=NO

xcodebuild archive \
 -scheme GRDBiOS \
 -project GRDB.xcodeproj \
 -archivePath ~/Desktop/GRDB-iphoneos.xcarchive \
 -sdk iphoneos \
 SKIP_INSTALL=NO

xcodebuild -create-xcframework \
 -framework ~/Desktop/GRDB-iphonesimulator.xcarchive/Products/Library/Frameworks/GRDB.framework \
 -framework ~/Desktop/GRDB-iphoneos.xcarchive/Products/Library/Frameworks/GRDB.framework \
 -output ~/Desktop/GRDB.xcframework