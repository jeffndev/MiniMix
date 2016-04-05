# MiniMix

A social, multi-track recording IDEA app, MiniMix allows you to create short recordings with the iPhone, layer up to 6 tracks, mix the volume of each track and produce a cool, easy to produce music Mix.

It is suggested that you use earphones for multitrack layering so that there is minimal track blead into each other.

The reason MiniMix is Social, is that you can Register with the MiniMix server API, upload your mixes (as well as continually sync up any changes) and make them searchable to the MiniMix community.

On the Community Tab of the app, you can go and search for mixes that have been uploaded, using any terms that might be found in the mix, the artist, the genre, title, description.  Searching allows you to preview play a mix and keep it in your own Community catalogue page for your future inspiration.

Much of the functionality related to your own mixes is available through left-swipe buttons on the table-view cells.  You can Edit the meta-information of your mix, Remix or add tracks, Delete a mix and Share the mix with the community.  

Additional functionality include full re-synch of your Cloud Shared mixes back to your other devices if you register using your same email/password combination. You can also share any of your own mixes as individual mp4 files, using the Share action toolbutton whenever a mix cell is selected.

The backend of MiniMix uses Token Authorization security so passwords (which are always encrypted) are rarely sent back and forth over the wire.

The MiniMix Community API was developed by this same author as a custom Ruby on Rails application, hosted on Heroku, and search features were implemented with advanced postgresql ts_vector technology for quick and smart searches.  The raw audio files are kept on Amazon S3 and uploaded through the API.


