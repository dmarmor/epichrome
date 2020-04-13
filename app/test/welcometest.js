describe("vcmp", () => {
    it("returns -1 if v1 < v2", () => {
	expect(vcmp('1.0.0', '2.3.0')).toEqual(-1);
	expect(vcmp('4.99.0', '10.0.0b3')).toEqual(-1);
    });
    it("returns 1 if v1 > v2", () => {
	expect(vcmp('2.3.0', '1.0.0')).toEqual(1);
    });
    it("returns 0 if v1 == v2", () => {
	expect(vcmp('3.1.2b3', '03.01.002b003')).toEqual(0);
    });
    it("treats beta as < release", () => {
	expect(vcmp('12.100.020b99', '012.100.20')).toEqual(-1);
    });
    it("turns an unparsable v1 into 0.0.0", () => {
	expect(vcmp('3.x1.2b3', '03.01.002b003')).toEqual(-1);
    });
    it("turns an unparsable v2 into 0.0.0", () => {
	expect(vcmp('3.1.2b3', '03.01b.002b003')).toEqual(1);
    });
    it("correctly compares versions with build numbers", () => {
	expect(vcmp('13.033.7b12', '0013.33.07b012[100]')).toEqual(1);
    expect(vcmp('04.3.12[1000]', '4.03.12[3938]')).toEqual(-1);
    });
});
