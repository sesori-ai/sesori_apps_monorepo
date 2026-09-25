const v2SessionFixture = <String, dynamic>{
  "id": "session-fixture",
  "projectID": "project-fixture",
  "cost": 0,
  "tokens": <String, dynamic>{
    "input": 0,
    "output": 0,
    "reasoning": 0,
    "cache": <String, dynamic>{"read": 0, "write": 0},
  },
  "time": <String, dynamic>{"created": 1, "updated": 1},
  "location": <String, dynamic>{"directory": "/fixture/project"},
};

const v2LocationFixture = <String, dynamic>{
  "directory": "/fixture/project",
  "project": <String, dynamic>{
    "id": "project-fixture",
    "directory": "/fixture/project",
    "canonical": "/fixture/project",
  },
};
