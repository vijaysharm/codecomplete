// debugger;
var program = {};

function minHeightBst(array) {
	return constructMinHeightBst(array, null, 0, array.length - 1);
  }

  function constructMinHeightBst(array, bst, startIdx, endIdx) {
	if (endIdx < startIdx) return;
	const midIdx = Math.floor((startIdx + endIdx) / 2);
	const valueToAdd = array[midIdx];
	if (bst === null) {
	  bst = new BST(valueToAdd);
	} else {
	  bst.insert(valueToAdd);
	}
	constructMinHeightBst(array, bst, startIdx, midIdx - 1);
	constructMinHeightBst(array, bst, midIdx + 1, endIdx);
	return bst;
  }

  class BST {
	constructor(value) {
	  this.value = value;
	  this.left = null;
	  this.right = null;
	}

	insert(value) {
	  if (value < this.value) {
		if (this.left === null) {
		  this.left = new BST(value);
		} else {
		  this.left.insert(value);
		}
	  } else {
		if (this.right === null) {
		  this.right = new BST(value);
		} else {
		  this.right.insert(value);
		}
	  }
	}
  }

program.minHeightBst = minHeightBst;

const chai = Chai.chai;

var results = [];
function it(description, test)  {
	var run = {name: description, success: false, message: null, actual: null, expected: null};
	try {
		test();
		run.success = true;
	} catch(exception) {
		run.message = exception.message;
		run.actual = exception.actual;
		run.expected = exception.expected;
	}

	results.push(run);
}

function validateBst(tree) {
  return validateBstHelper(tree, -Infinity, Infinity);
}
function validateBstHelper(tree, minValue, maxValue) {
  if (tree === null) return true;
  if (tree.value < minValue || tree.value >= maxValue) return false;
  const leftIsValid = validateBstHelper(tree.left, minValue, tree.value);
  return leftIsValid && validateBstHelper(tree.right, tree.value, maxValue);
}
function inOrderTraverse(tree, array) {
  if (tree !== null) {
    inOrderTraverse(tree.left, array);
    array.push(tree.value);
    inOrderTraverse(tree.right, array);
  }
  return array;
}
function getTreeHeight(tree, height = 0) {
  if (tree === null) return height;
  const leftTreeHeight = getTreeHeight(tree.left, height + 1);
  const rightTreeHeight = getTreeHeight(tree.right, height + 1);
  return Math.max(leftTreeHeight, rightTreeHeight);
}
it('Test Case #1', function () {
  const array = [1,2,5,7,10,13,14,15,22];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #2', function () {
  const array = [1];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(1);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #3', function () {
  const array = [1,2];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(2);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1,2];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #4', function () {
  const array = [1,2,5];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(2);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #5', function () {
  const array = [1,2,5,7];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #6', function () {
  const array = [1,2,5,7,10];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #7', function () {
  const array = [1,2,5,7,10,13];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #8', function () {
  const array = [1,2,5,7,10,13,14];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #9', function () {
  const array = [1,2,5,7,10,13,14,15];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #10', function () {
  const array = [1,2,5,7,10,13,14,15,22];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #11', function () {
  const array = [1,2,5,7,10,13,14,15,22,28];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #12', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #13', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32,36];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #14', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #15', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #16', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92,9000];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92, 9000];
  chai.expect(inOrder).to.deep.equal(expected);
});
it('Test Case #17', function () {
  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92,9000,9001];
  const tree = program.minHeightBst(array);
  chai.expect(validateBst(tree)).to.deep.equal(true);
  chai.expect(getTreeHeight(tree)).to.deep.equal(5);
  const inOrder = inOrderTraverse(tree, []);
  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92, 9000, 9001];
  chai.expect(inOrder).to.deep.equal(expected);
});



console.log(results.map(result => `${result.name}: ${result.message}`));
debugger;
