# VirtualTourist

## What it is
This is an iPhone-only app developed as the final project for the Udacity course
[iOS Persistence and Core Data](https://www.udacity.com/course/ios-persistence-and-core-data--ud325).

This was written to work with Swift 2.1.

## What it does
The app lets you drop pins on a map.  When you drop a pin, photo thumbnails associated with that location
are downloaded from Flickr and stored locally.  The pins and their associated photo's information are stored
using Core Data; the photos themselves are stored on the filesystem.

Tapping on an existing pin shows a collection view with the associated photos.  Inside the collection view,
tapping on a photo removes it from the collection.  A slightly longer press on the photo will show a detail
view of the photo (a larger version is fetched from Flickr).  In the detail view, you can zoom in and pan
around on the photo.  A finger tap will hide / show the navigation and status bars.

## Implementation notes
Usage of third party code libraries was intentionally avoided in order to comply with the Udacity project guidelines.
However, the networking code is mostly taken from a previous Udacity project; this web client networking code is
more complicated than it needs to be for the basic requirements of this project.

### Concurrent NSOperation subclasses
It is perhaps overkill to use NSOperations for this project; I did it because I wanted to learn about using NSOperations.
So, the code is likely more complicated than strictly necessary to accomplish the goals of the project.  The possibility
to be able to declare dependencies between operations is quite nice, though.

Two primary operations are used:

* ``SearchOperation``: Gets the list of photos for a dropped pin's location from Flickr; this may involve several network
  requests if there are several pages of results. For the purpose of this project, the Flickr results-per-page are
  restricted to 5, and 3 pages of results are shown in the collection view.  This behaviour is there just an exercise
  to use dependendent concurrent network connections.

* ``DownloadFilesOperation``: Downloads all of the not-yet downloaded files that were retrieved by a ``SearchOperation``,
  using ``DownloadSingleFileOperation``s.

* ``DownloadSingleFileOperation``: Downloads a single file.  If the operation is cancelled, the file download
  task will also be cancelled (if it's started).  The downloading of individual files is done on a queue that
  allows a maximum of 5 concurrent operations.

``DownloadFilesOperation`` is made dependant on the ``SearchOperation``, so downloading files will not start
until the full list of photos has been fetched.  Once the ``SearchOperation`` is complete, the correct number
of placeholder photos can be displayed in the collection view.  As files are downloaded, the placeholder images
are replaced with the downloaded images.

### Robustness
When the application is terminated by the user, the state in persisted in such a way that when the app is launched
again, the relevant operations (e.g. ``SearchOperation`` and ``DownloadFilesOperation``, or only ``DownloadFileOperation``)
can be started again if necessary.

When the application starts, it updates the photo data fetching / image downloading state for any pins that do not
have a reasonable value; this handles the case where the application was killed without having a chance to perform
it's clean-up tasks.

### Parent / Child Core Data implementation
The parent NSManagedObjectContext is using ``PrivateQueueConcurrencyType``, and the child context uses ``MainQueueConcurrencyType``.
This allows the slower persist-to-sqlite action to happen on a background thread.

### Detached error alert presentation
The current view controller may not have any knowledge of an error that happens during background processing, but the user
should be notified of these errors sometimes.  If an error occurs while downloading photo metadata or image files, an
error alert is presented on the view controller that is currently in the foreground.

### NSFetchedResultsController used for UICollectionView
Altough designed to work with table views, the fetched results controller can also simplify the code for managing
changes in collection views; it is used to that effect in this project.

## Attributions
Thanks to [Font Awesome](http://fontawesome.io) for it's great open-source SVG fonts; the photo placeholder image
is taken from there.

## History
* Version 1.0: January, 2016.
