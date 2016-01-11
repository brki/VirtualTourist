# VirtualTourist

## What is it
This is an iPhone-only app developed as the final project for the Udacity course
[iOS Persistence and Core Data](https://www.udacity.com/course/ios-persistence-and-core-data--ud325).

This was written to work with Swift 2.1.

## What does it do
The app lets you drop pins on a map.  When you drop a pin, photo thumbnail associated with that location
are downloaded from Flickr and stored locally.  Tapping on an existing pin shows a collection view
with the associated photos.  Inside the collection view, tapping on a photo removes it from the collection.
The pins and their associated photo's information are stored using Core Data; the photos themselves are
stored on the filesystem.

## Implementation notes
Usage of third party code libraries was intentionally avoided in order to comply with the Udacity project guidelines.

### Concurrent NSOperation subclasses
It is perhaps overkill to use NSOperations for this project; I did it because I wanted to learn about using NSOperations.
So, the code is likely more complicated than strictly necessary to accomplish the goals of the project.

Two primary operations are used:

* ``SearchOperation``: Gets the list of photos for a dropped pin's location from Flickr; this may involve several network
  requests if there are several pages of results. As configured, it will try to fetch up to 600 results; Flickr limits
  the geo-based queries to 250 results per page.

* ``DownloadFilesOperation``: Downloads all of the not-yet downloaded files that were retrieved by a ``SearchOperation``.
  The downloading of individual files is done on a queue that allows a maximum of 5 concurrent operations.

``DownloadFilesOperation`` is made dependant on the ``SearchOperation``, so downloading files will not start
until the full list of photos has been fetched.  Once the ``SearchOperation`` is complete, the correct number
of placeholder photos can be displayed in the collection view.  As files are downloaded, the placeholder images
are replaced with the downloaded images.

### Robustness
When the application is terminated by the user, the state in persisted in such a way that when the app is launched
again, the relevant operations (e.g. ``SearchOperation`` and ``DownloadFilesOperation, or only ``DownloadFileOperation``)
can be started again if necessary.

When the application starts, it updates the photo data fetching / image downloading state for any pins that do not
have a reasonable value; this handles the case where the application was killed without having a chance to perform
it's clean-up tasks.

## Attributions
Thanks to [Font Awesome](http://fontawesome.io) for it's great open-source SVG fonts; the photo placeholder image
is taken from there.

## History
* Version 1.0: January, 2016.
