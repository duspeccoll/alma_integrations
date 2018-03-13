# Alma/ArchivesSpace Integrations

This plugin provides integrations between the ArchivesSpace archival collection management system and the Alma library management system from Ex Libris. It is built on the [Top Container](https://github.com/hudmol/container_management) functionality that Hudson Molonglo developed for ArchivesSpace. Based on the Resource record provided by a user, the integrations will perform the following API calls:

* Check for a BIB with the Resource's MMS ID
* Check for holdings associated with the BIB identified by that MMS ID

Additionally, the integrations allow a user to add new holdings, create a new BIB record if no MMS ID is present or the provided MMS ID does not match any BIB record in Alma, or sync changes to a Resource in ArchivesSpace with the BIB record uniquely identified by the Resource's MMS ID.

# Prerequisites

## For your Resource record

You will need to have a data element in your ArchivesSpace Resources assigned to the MMS IDs for their Alma bibliographic records, so that the API calls have an identifier against which to check. The University of Denver records MMS IDs in User Defined String 2; for now, this plugin assumes you also do this. Future development will allow this field to be configured on a per-instance basis.

## For your config.rb file

You will need to add two configuration settings to your config.rb file for these integrations to work:

* **AppConfig[:alma_api_url]** represents the URL you use to access the Alma API. These are region-specific; find yours [here](https://developers.exlibrisgroup.com/alma/apis#calling).
* **AppConfig[:alma_apikey]** is the specific API key you use to access the Alma APIs. You may need to consult with your library IT department to access an API key to use for this plugin. If you would like to test API calls against the Alma sandbox, you may request a personal API key through the Alma Developer Network; instructions for this may be found [here](https://developers.exlibrisgroup.com/alma/apis#logging).

# Using the integrations

The integrations may be accessed via the repository menu:

![Access the plugin by clicking on the repository menu dropdown. Hover over "Plugins," then select "Alma Integrations."](http://jackflaps.net/img/plugin_menu.png)

The index view displays a Resource linker. Select the Resource you wish to integrate with Alma and click "Search." ArchivesSpace will perform two API calls using the MMS ID of the Resource selected -- one to check if a BIB record exists with that MMS ID, and a second to check on that BIB's holdings. Once the calls have been made, the results will appear as seen in the screenshot below:

![Alma integration results. There are three subrecords in the results view: the first for BIB record status, the second for existing holdings, and the third for a dropdown menu allowing the user to add new holdings.](http://jackflaps.net/img/plugin_output.png)

## Syncing Resources with Alma

The integrations will check for an MMS ID associated with a Resource. If it finds one, it will ask if you would like to push the ArchivesSpace Resource metadata, serialized in MARC21, to the Alma BIB record having that MMS ID. If it does not find one, it will ask if you would like to create a new record. (Note that Alma's default is to suppress new records created via the API; for now you will need to use the Metadata Editor to un-suppress the record manually if you would like it published to Primo.)

Beware: This plugin assumes ArchivesSpace is your metadata system of record. It has no way to pull changes made in Alma into ArchivesSpace.

## Adding new holdings

Currently the plugin has a hard-coded list of locations used at DU for housing Special Collections and Archives materials. In the Add New Holdings subrecord, ArchivesSpace will check the list of holdings it received from its Alma API call; any holdings locations in this list that do not already exist in Alma will be added to the dropdown menu. If desired, the user may select the unused holdings location they wish to associate with the Resource's BIB record, then click on the "Add" button. ArchivesSpace will attempt to post the new holdings to Alma, then return to the plugin index page. If successful, the new Holdings ID will be returned; if not, the plugin will return the error message it gets back from the Alma API.

# Future Development

* Allow for instance-defined holdings locations, or at least better indicate how an individual Alma user might customize the Holdings code for their specific instance
* Allow an ArchivesSpace instance to configure its own fields for MMS IDs
* See if it's possible to integrate Top Containers with Alma's circulation APIs??????????????????

# In Conclusion

Feel free to kick the tires on this against your own ArchivesSpace/Alma environment and let me know how it works. Questions, comments, and/or pull requests welcome! E-mail: kevin.clair [at] du.edu.
