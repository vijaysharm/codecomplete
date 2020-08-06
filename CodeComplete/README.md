#  Code Complete

## TODOs

List of characters used in all solutions (90 characters):  !"$%&'()*+,-./012345689:;<=>?ABCDEFGHIJKLMNOPRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}

### Version 1.3
	* [ ] Show Progress
	* [ ] Show x of y failed/passed tests
	* [ ] Push notifications

### Version X
      * [ ] If compilation error happens, and console is shown, should we show a toast to say "go back to code"? 
	* [ ] Analytics
	* [ ] Fix bst-construction and linked-list-construction tests
	* [ ] Sort problems appropriately
	* [ ] Improve code highlighting in source code editor
	* [ ] Improve overall app styling
	* [ ] Implement Filter button
	* [ ] Implement "starring" questions
	* [ ] Support themes
	* [ ] Implement "whiteboard" mode. Allow users to write their answers on a canvas
		* [ ] Is it possible to convert the handwritten code to actual code to be run?
	* [ ] Add toast suggesting the user take a hint after X seconds of idle
	* [ ] Support increasing font size
	* [ ] Have user editable tests
	
### Version 1.1 / 1.2
	* [x] Add timer
	* [x] Show console on compilation failure (not test tab)
	* [x] Make prompt a webview for better styling
	* [x] Include Facebook SDK for purchase tracking
	
### Version 1	
	* [x] Show question test status "passed", "fail", etc...
	* [x] Marketing copy and images
	* [x] App Landing page
	* [x] Support full screen (source panel takes over the prompt panel)
	* [x] Leave Feedback
	* [x] Create App Icon
	* [x] Splash page
	* [x] Create settings page
		* [x] Includes restore purchase
		* [x] TOS + Privacy page
	* [x] Create purchase page
		* [x] Create Revenue Cat page
		* [x] Create product in iTunes Connect
		* [x] Show question locked status
	* [x] Show success/fail status in question view
	* [x] update success/fail status in question list
	* [x] Show answers from running solutions
	* [x] If tests are "tapped to reveal", remember the next time the tests are run
	* [x] If running tests take too long, disable run button and execute on separate thread
	* [x] Show test results in question page (pass/fail)
	* [x] Section headers on problem list (include number of questions in section)
	* [x] Support saving solutions
	* [x] Fix some tests where the StartingTest won't work (See Node Depth question)
	* [x] Fix some tests where the number of tests in StartingTest don't match JSONTests (See Binary search question)
	* [x] Order JSONTests and JSONAnswers to match StartingTest (See Palindrome Check)
	* [x] Make solutions runnable (we don't get back the actual solution)
	* [x] Replace copyright notice in json files
	* [x] Improve the prompt styling (make sure code styling matches editor styles)
	* [x] Show tests in question page
	* [x] Make solutions hideable

## Recreating chai.js file

Currently, we're using chai.js to run the tests in the JSON files. The last version of chai used was 4.2.0. In case it ever needs to be recreate that file, here are the steps I took

	* in the Resources directory of this project, run `npm init -y`
	* Add chai as a dependency `npm install chai --save`
	* Add a file to the directory named `main.js` and add the following line `module.exports.chai = require('chai');`
	* Make sure you have browserify installed. Version last used to generate the file is `16.5.1`, installed with command `npm install -g browserify`
	* Generate the chai.js file as follows: `browserify main.js --standalone Chai > chai.js`
	* Add the file to Xcode. Note that the Javascript engine expects tthe file to be named chai.js

## Deploying to store

	* Not tested yet, however, we're currently configured to use Fastlane. When a successful deployment is complete, update this doc. 
	* The last deploy was done manually through Xcode. May need to copy Fastlane configuration from Colouring book.

## Fixing tests

	There are some tests in the JSON file that don't work. I ended up using the index.js file in the ~/programming/node/code directory to generate tests using the JSONTests and JSONAnswers from the json file. If the tests arent obviously generated, or are failing, I would copy the generated tests and copy them into the index.js file found in the resources directory of this project. Then you can run the test in a browser to see where it might be failing. 
