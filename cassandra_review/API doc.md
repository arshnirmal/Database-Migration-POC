# 1. User Session API

## Endpoint
**POST** `/api/user/session`

## Path parameters
None

## Query String
None

## Auth Headers / Tokens
*Note: Frontend retrieves third party token from cookies/function and passes it in Source Token header*
```
Content-Type: application/json
x-source-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

### Login Platform Source
| Value | Description |
|-------|-------------|
| 1     | Facebook    |
| 2     | Google      |
| 3     | Others      |

## Request Payload
```json
{
    "device_id": 1,
    "login_platform_source": 1
}
```

## Response Json
```json
{
    "data": {
        "device_id": 1,
        "guid": "a5a74150-364f-4a2a-baab-e4a5d37835ea",
        "source_id": "1234567890",
        "user_name": "Shreyas(urlencode)",
        "first_name": "Shreyas(urlencode)",
        "last_name": "Shreyas(urlencode)",
        "profanity_status": 1,
        "preferences_saved": true,
        "login_platform_source": 1,
        "user_session": {
            "game_token": "<jwt_token>",
            "created_at": "2025-06-11T07:06:36.000Z",
            "expires_at": "2025-06-12T07:06:36.000Z"
        },
        "user_properties": [
            {
                "key": "residence_country",
                "value": "IN"
            },
            {
                "key": "subscription_active",
                "value": "1"
            },
            {
                "key": "profile_pic_url",
                "value": "https://uefa.com/images/1234567890.png"
            }
        ]
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

# 2. User Game Summary API

## Endpoint
**GET** `/api/user/{guid}/game-summary`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Response Json
```json
{
    "data": {
        "overall": {
            "total_points": "175",
            "rank": 10,
            "team_created_count": 3,
            "max_team_allowed": 5,
            "teams": [
                {
                    "team_no": 1,
                    "team_name": "Team 1(urlencode)",
                    "points": "100",
                    "rank": 44
                },
                {
                    "team_no": 2,
                    "team_name": "Team 2(urlencode)",
                    "points": "100",
                    "rank": 44
                },
                {
                    "team_no": 3,
                    "team_name": "Team 3(urlencode)",
                    "points": "100",
                    "rank": 44
                }
            ]
        },
        "gamesets": [
            {
                "event_group": {
                    "phase_id": 1,
                    "gameset_id": 4,
                    "gameday_id": 1,
                    "gameset_number": 1,
                    "gameday_number": 1,
                    "gameset_status": 1,
                    "gameday_status": 1
                },
                "total_points": "175",
                "team_created_count": 3,
                "max_team_allowed": 5,
                "is_current_gameset": true,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1006,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "489"
                            },
                            {
                                "player_id": 1011,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "290"
                            },
                            {
                                "player_id": 1007,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "300"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 3,
                            "extra_made": 2,
                            "total_made": 5
                        },
                        "boosters": [
                            {
                                "booster_id": 1,
                                "player_id": 1006
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 85,
                            "left": 15
                        },
                        "points": null,
                        "rank": 0
                    },
                    {
                        "team_no": 2,
                        "team_name": "Team 2(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1003,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "350"
                            },
                            {
                                "player_id": 1007,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "200"
                            },
                            {
                                "player_id": 1009,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "180"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 3,
                            "extra_made": 0,
                            "total_made": 3
                        },
                        "boosters": [],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 78,
                            "left": 22
                        },
                        "points": "45",
                        "rank": 18
                    },
                    {
                        "team_no": 3,
                        "team_name": "Team 3(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1002,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "320"
                            },
                            {
                                "player_id": 1008,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "180"
                            },
                            {
                                "player_id": 1012,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "160"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 2,
                            "extra_made": 0,
                            "total_made": 2
                        },
                        "boosters": [
                            {
                                "booster_id": 2,
                                "player_id": 1002
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 82,
                            "left": 18
                        },
                        "points": "45",
                        "rank": 19
                    }
                ]
            },
            {
                "event_group": {
                    "phase_id": 1,
                    "gameset_id": 1,
                    "gameday_id": 1,
                    "gameset_number": 1,
                    "gameday_number": 1,
                    "gameset_status": 1,
                    "gameday_status": 1
                },
                "total_points": "200",
                "team_created_count": 2,
                "max_team_allowed": 5,
                "is_current_gameset": false,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1007,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "450"
                            },
                            {
                                "player_id": 1010,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "250"
                            },
                            {
                                "player_id": 1008,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "280"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 1,
                            "extra_made": 0,
                            "total_made": 1
                        },
                        "boosters": [
                            {
                                "booster_id": 1,
                                "player_id": 1010
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 88,
                            "left": 12
                        },
                        "points": "120",
                        "rank": 8
                    },
                    {
                        "team_no": 2,
                        "team_name": "Team 2(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1002,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "380"
                            },
                            {
                                "player_id": 1003,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "220"
                            },
                            {
                                "player_id": 1005,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "260"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 1,
                            "extra_made": 0,
                            "total_made": 1
                        },
                        "boosters": [],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 75,
                            "left": 25
                        },
                        "points": "80",
                        "rank": 12
                    }
                ]
            },
            {
                "event_group": {
                    "phase_id": 1,
                    "gameset_id": 2,
                    "gameday_id": 2,
                    "gameset_number": 2,
                    "gameday_number": 2,
                    "gameset_status": 1,
                    "gameday_status": 1
                },
                "total_points": "150",
                "team_created_count": 2,
                "max_team_allowed": 5,
                "is_current_gameset": false,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1008,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "400"
                            },
                            {
                                "player_id": 1009,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "230"
                            },
                            {
                                "player_id": 1012,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "270"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 1,
                            "extra_made": 0,
                            "total_made": 1
                        },
                        "boosters": [
                            {
                                "booster_id": 1,
                                "player_id": 1009
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 79,
                            "left": 21
                        },
                        "points": "75",
                        "rank": 15
                    },
                    {
                        "team_no": 2,
                        "team_name": "Team 2(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1001,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "360"
                            },
                            {
                                "player_id": 1004,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "210"
                            },
                            {
                                "player_id": 1013,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "240"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 3,
                            "extra_made": 0,
                            "total_made": 3
                        },
                        "boosters": [
                            {
                                "booster_id": 2,
                                "player_id": 1001
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 86,
                            "left": 14
                        },
                        "points": "75",
                        "rank": 16
                    }
                ]
            },
            {
                "event_group": {
                    "phase_id": 2,
                    "gameset_id": 3,
                    "gameday_id": 3,
                    "gameset_number": 3,
                    "gameday_number": 3,
                    "gameset_status": 1,
                    "gameday_status": 1
                },
                "total_points": "300",
                "team_created_count": 3,
                "max_team_allowed": 5,
                "is_current_gameset": false,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1007,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "480"
                            },
                            {
                                "player_id": 1010,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "260"
                            },
                            {
                                "player_id": 1014,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "310"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 3,
                            "extra_made": 0,
                            "total_made": 3
                        },
                        "boosters": [
                            {
                                "booster_id": 1,
                                "player_id": 1007
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 92,
                            "left": 8
                        },
                        "points": "120",
                        "rank": 5
                    },
                    {
                        "team_no": 2,
                        "team_name": "Team 2(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1002,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "420"
                            },
                            {
                                "player_id": 1003,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "240"
                            },
                            {
                                "player_id": 1015,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "290"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 2,
                            "extra_made": 0,
                            "total_made": 2
                        },
                        "boosters": [],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 71,
                            "left": 29
                        },
                        "points": "90",
                        "rank": 8
                    },
                    {
                        "team_no": 3,
                        "team_name": "Team 3(urlencode)",
                        "profanity_status": 1,
                        "players": [
                            {
                                "player_id": 1001,
                                "is_captain": true,
                                "is_vice_captain": false,
                                "player_level": 1,
                                "points": "440"
                            },
                            {
                                "player_id": 1005,
                                "is_captain": false,
                                "is_vice_captain": true,
                                "player_level": 2,
                                "points": "270"
                            },
                            {
                                "player_id": 1016,
                                "is_captain": false,
                                "is_vice_captain": false,
                                "player_level": 2,
                                "points": "320"
                            }
                        ],
                        "transfers": {
                            "free_limit": 3,
                            "free_made": 0,
                            "extra_made": 0,
                            "total_made": 0
                        },
                        "boosters": [
                            {
                                "booster_id": 3,
                                "player_id": 1001
                            },
                            {
                                "booster_id": 4,
                                "player_id": 1005
                            }
                        ],
                        "formation": [
                            {
                                "skill_id": 1,
                                "player_count": 4
                            },
                            {
                                "skill_id": 2,
                                "player_count": 4
                            },
                            {
                                "skill_id": 3,
                                "player_count": 2
                            },
                            {
                                "skill_id": 4,
                                "player_count": 1
                            }
                        ],
                        "budget": {
                            "limit": 100,
                            "utilized": 95,
                            "left": 5
                        },
                        "points": "90",
                        "rank": 9
                    }
                ]
            }
        ]
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

# 3. Game Summary Lite API

## Endpoint
**GET** `/api/user/{guid}/game-summary-lite`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Response Json
```json
{
    "data": {
        "gamesets": [
            {
                "gameset_id": 4,
                "total_points": "175",
                "team_created_count": 3,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "points": "100",
                        "rank": 44,
                        "is_late_onboarded": true
                    },
                    {
                        "team_no": 2,
                        "team_name": "Team 1(urlencode)",
                        "points": "120",
                        "rank": 44
                    }
                ]
            },
            {
                "gameset_id": 5,
                "total_points": "175",
                "team_created_count": 3,
                "teams": [
                    {
                        "team_no": 1,
                        "team_name": "Team 1(urlencode)",
                        "points": "100",
                        "rank": 44
                    }
                ]
            }
       ]
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 4. Teams Summary API

## Endpoint
**GET** `/api/user/{guid}/teams-summary`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Response Json
```json
{
    "data": {
        "overall": {
            "total_points": "175",
            "rank": 10,
            "team_created_count": 3,
            "max_team_allowed": 5,
            "teams": [
                {
                    "team_no": 1,
                    "team_name": "Team 1(urlencode)",
                    "points": "100",
                    "rank": 44,
                    "created_gameset_id": 1
                },
                {
                    "team_no": 2,
                    "team_name": "Team 2(urlencode)",
                    "points": "100",
                    "rank": 44,
                    "created_gameset_id": 1
                },
                {
                    "team_no": 3,
                    "team_name": "Team 3(urlencode)",
                    "points": "100",
                    "rank": 44,
                    "created_gameset_id": 1
                }
            ]
        }
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 5. Game State API

## Endpoint
**GET** `/api/user/{guid}/game-state`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Response Json
```json
{
    "data": {
        "current_gameset": {
            "phase_id": 1,
            "gameset_id": 4,
            "gameday_id": 1,
            "gameset_number": 1,
            "gameday_number": 1,
            "late_onboard": null,
            "gameset_status": 1,
            "gameday_status": 1
        },
        "first_gameset": {
            "phase_id": 1,
            "gameset_id": 1,
            "gameday_id": 1,
            "gameset_number": 1,
            "gameday_number": 1,
            "late_onboard": true,
            "gameset_status": 1,
            "gameday_status": 1
        }
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---


# 6. Name Availability API

## Endpoint
**POST** `/api/user/name-availability`

*Note: Uses POST instead of GET to protect sensitive data (emails, mobile numbers) in request body*

## Path parameters
None

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Type
| Value | Description                    |
|-------|--------------------------------|
| 1     | Username availability check    |
| 2     | Team name availability check   |
| 3     | League name availability check |

## Request Payload
```json
{
    "type": 1,
    "value": "john_doe"
}
```

**Sample Payloads for each type:**

```json
// Username check
{
    "type": 1, 
    "value": "john_doe"
}

// Team name check
{
    "type": 2, 
    "value": "ManchesterUnited"
}

// League name check
{
    "type": 3, 
    "value": "XYZ"
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 7. User Preferences API

## Endpoint
**POST** `/api/user/{guid}/preferences`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Preference Types
| Value                   | Description                    |
|------------------------|--------------------------------|
| team_1                 | First team preference          |
| team_2                 | Second team preference         |
| player_1               | First player preference        |
| player_2               | Second player preference       |
| tnc                    | Terms and conditions           |

## Request Payload
```json
{
    "preferences": [
        {
            "preference": "team_1",
            "value": 1
        },
        {
            "preference": "team_2",
            "value": 2
        },
        {
            "preference": "player_1",
            "value": 2
        },
        {
            "preference": "player_2",
            "value": 6
        },
        {
            "preference": "tnc",
            "value": 1
        }
    ]
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "SUCCESS",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```
---

# 8. User Profile API

## Endpoint
**GET** `/api/user/{guid}/profile`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

### Login Platform Source
| Value | Description |
|-------|-------------|
| 1     | Facebook    |
| 2     | Google      |
| 3     | Others      |

### Profanity Status
| Value | Description |
|-------|-------------|
| 1     | Not Profane |
| 2     | Profane     |
| 3     | Updated by system |

### Preference Types (in user_preferences array)
| Value                   | Description                    |
|------------------------|--------------------------------|
| country                | Country preference             |
| team_1                 | First team preference          |
| team_2                 | Second team preference         |
| player_1               | First player preference        |
| player_2               | Second player preference       |
| tnc                    | Terms and conditions           |

## Response Json
```json
{
    "data": {
        "device_id": 1,
        "guid": "a5a74150-364f-4a2a-baab-e4a5d37835ea",
        "source_id": "1234567890",
        "user_name": "Shreyas(urlencode)",
        "first_name": "Shreyas(urlencode)",
        "last_name": "Shreyas(urlencode)",
        "profanity_status": 1,
        "preferences_saved": true,
        "login_platform_source": 1,
        "user_properties": [
            {
                "key": "residence_country",
                "value": "IN"
            },
            {
                "key": "subscription_active",
                "value": "1"
            },
            {
                "key": "profile_pic_url",
                "value": "https://uefa.com/images/1234567890.png"
            }
        ],
        "user_preferences": [
            {
                "preference": "country",
                "value": 1
            },
            {
                "preference": "team_1",
                "value": 1
            },
            {
                "preference": "team_2",
                "value": 2
            },
            {
                "preference": "player_1",
                "value": 2
            },
            {
                "preference": "player_2",
                "value": 6
            },
            {
                "preference": "tnc",
                "value": 1
            }
        ]
    },
    "meta": {
        "retval": 1,
        "message": "SUCCESS",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 9. Save Team API

## Endpoint
**POST** `/api/user/{guid}/save-team`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

### Login Platform Source
| Value | Description |
|-------|-------------|
| 1     | Facebook    |
| 2     | Google      |
| 3     | Others      |

### Profanity Status
| Value | Description |
|-------|-------------|
| 1     | Not Profane |
| 2     | Profane     |
| 3     | Updated by system |

## Request Payload
```json
{
    "device_id": 1,
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "captain_id": 1,
    "vice_captain_id": 0,
    "booster": {
        "booster_id": 1,
        "entity_id": 1
    },
    "inplay_entities": [
        {
            "entity_id": 1,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 2,
            "skill_id": 1,
            "order": 2
        },
        {
            "entity_id": 3,
            "skill_id": 1,
            "order": 3
        },
        {
            "entity_id": 4,
            "skill_id": 1,
            "order": 4
        },
        {
            "entity_id": 5,
            "skill_id": 1,
            "order": 5
        },
        {
            "entity_id": 6,
            "skill_id": 1,
            "order": 6
        },
        {
            "entity_id": 7,
            "skill_id": 1,
            "order": 7
        },
        {
            "entity_id": 8,
            "skill_id": 1,
            "order": 8
        },
        {
            "entity_id": 9,
            "skill_id": 1,
            "order": 9
        },
        {
            "entity_id": 10,
            "skill_id": 1,
            "order": 10
        },
        {
            "entity_id": 11,
            "skill_id": 1,
            "order": 11
        }
    ],
    "reserved_entities": [
        {
            "entity_id": 12,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 13,
            "skill_id": 1,
            "order": 2
        },
        {
            "entity_id": 14,
            "skill_id": 1,
            "order": 3
        },
        {
            "entity_id": 15,
            "skill_id": 1,
            "order": 4
        }
    ],
    "team_name": "saitama(encoded)"
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 10. Transfers API

## Endpoint
**POST** `/api/user/{guid}/transfers`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

## Request Payload
```json
{
    "device_id": 1,
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "team_no": 1,
    "captain_id": 1,
    "vice_captain_id": 0,
    "booster": {
        "booster_id": 1,
        "entity_id": 13,
    },
    "entities_in": [
        {
            "entity_id": 13,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 14,
            "skill_id": 1,
            "order": 2
        }
    ],
    "entities_out": [
        {
            "entity_id": 12,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 13,
            "skill_id": 1,
            "order": 2
        }
    ]
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 11. Substitutions API

## Endpoint
**POST** `/api/user/{guid}/substitutions`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

### Position Types
| Value    | Description                 |
|----------|-----------------------------|
| inplay   | Active playing position     |
| reserve  | Reserve/bench position      |

## Request Payload
```json
{
    "device_id": 1,
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "team_no": 1,
    "captain_id": 1,
    "vice_captain_id": 0,
    "booster": {
        "booster_id": 1,
        "entity_id": 13,
    },
    "entities_in": [
        {
            "entity_id": 13,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 14,
            "skill_id": 1,
            "order": 2
        }
    ],
    "entities_out": [
        {
            "entity_id": 12,
            "skill_id": 1,
            "order": 1
        },
        {
            "entity_id": 13,
            "skill_id": 1,
            "order": 2
        }
    ] 
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 12. User Teams API

## Endpoint
**GET** `/api/user/{guid}/gameset/{gameset_id}/user-teams`

## Path parameters
- `guid` (string): User's unique identifier
- `gameset_id` (integer): Gameset identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Profanity Status
| Value | Description |
|-------|-------------|
| 1     | Not Profane |
| 2     | Profane     |
| 3     | Updated by system |

## Response Json
```json
{
    "data": {
        "team_created_count": 3,
        "max_team_allowed": 5,
        "rank": 10,
        "total_points": "175",
        "teams": [
            {
                "team_no": 1,
                "team_name": "Team 1(urlencode)",
                "profanity_status": 1,
                "transfers": {
                    "free_limit": 3,
                    "free_made": 3,
                    "extra_made": 2,
                    "total_made": 5
                },
                "boosters": [
                    {
                        "booster_id": 1,
                        "player_id": 1010
                    }
                ],
                "formation": [
                    {
                        "skill_id": 1,
                        "player_count": 4
                    },
                    {
                        "skill_id": 2,
                        "player_count": 4
                    },
                    {
                        "skill_id": 3,
                        "player_count": 2
                    },
                    {
                        "skill_id": 4,
                        "player_count": 1
                    }
                ],
                "budget": {
                    "limit": 100,
                    "utilized": 85,
                    "left": 15
                },
                "inplay_entities": [
                    {
                        "entity_id": 1001,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1002,
                        "skill_id": 1,
                        "order": 2
                    },
                    {
                        "entity_id": 1003,
                        "skill_id": 1,
                        "order": 3
                    },
                    {
                        "entity_id": 1004,
                        "skill_id": 1,
                        "order": 4
                    },
                    {
                        "entity_id": 1005,
                        "skill_id": 2,
                        "order": 5
                    },
                    {
                        "entity_id": 1006,
                        "skill_id": 2,
                        "order": 6
                    },
                    {
                        "entity_id": 1007,
                        "skill_id": 2,
                        "order": 7
                    },
                    {
                        "entity_id": 1008,
                        "skill_id": 2,
                        "order": 8
                    },
                    {
                        "entity_id": 1009,
                        "skill_id": 3,
                        "order": 9
                    },
                    {
                        "entity_id": 1010,
                        "skill_id": 3,
                        "order": 10
                    },
                    {
                        "entity_id": 1011,
                        "skill_id": 4,
                        "order": 11
                    }
                ],
                "reserved_entities": [
                    {
                        "entity_id": 1012,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1013,
                        "skill_id": 2,
                        "order": 2
                    },
                    {
                        "entity_id": 1014,
                        "skill_id": 3,
                        "order": 3
                    },
                    {
                        "entity_id": 1015,
                        "skill_id": 4,
                        "order": 4
                    }
                ],
                "points": null,
                "rank": 0
            },
            {
                "team_no": 2,
                "team_name": "Team 2(urlencode)",
                "profanity_status": 1,
                "transfers": {
                    "free_limit": 3,
                    "free_made": 3,
                    "extra_made": 0,
                    "total_made": 3
                },
                "boosters": [],
                "formation": [
                    {
                        "skill_id": 1,
                        "player_count": 4
                    },
                    {
                        "skill_id": 2,
                        "player_count": 4
                    },
                    {
                        "skill_id": 3,
                        "player_count": 2
                    },
                    {
                        "skill_id": 4,
                        "player_count": 1
                    }
                ],
                "budget": {
                    "limit": 100,
                    "utilized": 78,
                    "left": 22
                },
                "inplay_entities": [
                    {
                        "entity_id": 1001,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1002,
                        "skill_id": 1,
                        "order": 2
                    },
                    {
                        "entity_id": 1003,
                        "skill_id": 1,
                        "order": 3
                    },
                    {
                        "entity_id": 1004,
                        "skill_id": 1,
                        "order": 4
                    },
                    {
                        "entity_id": 1005,
                        "skill_id": 2,
                        "order": 5
                    },
                    {
                        "entity_id": 1006,
                        "skill_id": 2,
                        "order": 6
                    },
                    {
                        "entity_id": 1007,
                        "skill_id": 2,
                        "order": 7
                    },
                    {
                        "entity_id": 1008,
                        "skill_id": 2,
                        "order": 8
                    },
                    {
                        "entity_id": 1009,
                        "skill_id": 3,
                        "order": 9
                    },
                    {
                        "entity_id": 1010,
                        "skill_id": 3,
                        "order": 10
                    },
                    {
                        "entity_id": 1011,
                        "skill_id": 4,
                        "order": 11
                    }
                ],
                "reserved_entities": [
                    {
                        "entity_id": 1012,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1013,
                        "skill_id": 2,
                        "order": 2
                    },
                    {
                        "entity_id": 1014,
                        "skill_id": 3,
                        "order": 3
                    },
                    {
                        "entity_id": 1015,
                        "skill_id": 4,
                        "order": 4
                    }
                ],
                "points": "45",
                "rank": 18
            },
            {
                "team_no": 3,
                "team_name": "Team 3(urlencode)",
                "profanity_status": 1,
                "transfers": {
                    "free_limit": 3,
                    "free_made": 2,
                    "extra_made": 0,
                    "total_made": 2
                },
                "boosters": [
                    {
                        "booster_id": 2,
                        "player_id": 1002
                    }
                ],
                "formation": [
                    {
                        "skill_id": 1,
                        "player_count": 4
                    },
                    {
                        "skill_id": 2,
                        "player_count": 4
                    },
                    {
                        "skill_id": 3,
                        "player_count": 2
                    },
                    {
                        "skill_id": 4,
                        "player_count": 1
                    }
                ],
                "budget": {
                    "limit": 100,
                    "utilized": 82,
                    "left": 18
                },
                "inplay_entities": [
                    {
                        "entity_id": 1001,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1002,
                        "skill_id": 1,
                        "order": 2
                    },
                    {
                        "entity_id": 1003,
                        "skill_id": 1,
                        "order": 3
                    },
                    {
                        "entity_id": 1004,
                        "skill_id": 1,
                        "order": 4
                    },
                    {
                        "entity_id": 1005,
                        "skill_id": 2,
                        "order": 5
                    },
                    {
                        "entity_id": 1006,
                        "skill_id": 2,
                        "order": 6
                    },
                    {
                        "entity_id": 1007,
                        "skill_id": 2,
                        "order": 7
                    },
                    {
                        "entity_id": 1008,
                        "skill_id": 2,
                        "order": 8
                    },
                    {
                        "entity_id": 1009,
                        "skill_id": 3,
                        "order": 9
                    },
                    {
                        "entity_id": 1010,
                        "skill_id": 3,
                        "order": 10
                    },
                    {
                        "entity_id": 1011,
                        "skill_id": 4,
                        "order": 11
                    }
                ],
                "reserved_entities": [
                    {
                        "entity_id": 1012,
                        "skill_id": 1,
                        "order": 1
                    },
                    {
                        "entity_id": 1013,
                        "skill_id": 2,
                        "order": 2
                    },
                    {
                        "entity_id": 1014,
                        "skill_id": 3,
                        "order": 3
                    },
                    {
                        "entity_id": 1015,
                        "skill_id": 4,
                        "order": 4
                    }
                ],
                "points": "45",
                "rank": 19
            }
        ]
    },
    "meta": {
        "retval": 1,
        "message": "OK",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 13. Update Name API

## Endpoint
**POST** `/api/user/update-name`

## Path parameters
None

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

### Profanity Status
| Value | Description |
|-------|-------------|
| 1     | Not Profane |
| 2     | Profane     |
| 3     | Updated by system |

## Request Payload
```json
{
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "type": 1,
    "device_id": 1,
    "name_identifier": 1,           // TODO unique id (team no, league id, etc..)
    "name": "Manchester United FC(urlencode)"
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "SUCCESS",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

## Error Response (Name Not Available)
```json
{
    "data": null,
    "meta": {
        "retval": 2,
        "message": "NAME_UNAVAILABLE",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

## Error Response (Profanity Detected)
```json
{
    "data": null,
    "meta": {
        "retval": 3,
        "message": "PROFANITY_DETECTED",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 14. Change Captain and Vice Captain API

## Endpoint
**POST** `/api/user/{guid}/change-captains`

## Path parameters
- `guid` (string): User's unique identifier

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |

## Request Payload
```json
{
    "device_id": 1,
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "captain_id": 1006,
    "team_no": 1,
    "vice_captain_id": 1011,
    "booster": {
        "booster_id": 1,
        "entity_id": 13,
    },
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "SUCCESS",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

# 15. Apply Booster API

### Booster Types
| Booster ID | Name | Type | Requires Player ID |
|------------|------|------|-------------------|
| 1 | Double X Individual | Individual | Yes |
| 2 | Triple X Individual | Individual | Yes |
| 3 | Double X Team | Team | No |
| 4 | Unlimited Transfer | Team | No |
| 5 | Wildcard Transfer | Team | No |
| 6 | No Negative | Team | No |
| 7 | AutoPilot | Team | No |

## Endpoint
**POST** `/api/user/apply-booster-1`

**POST** `/api/user/apply-booster-2`

**POST** `/api/user/apply-booster-3`

**POST** `/api/user/apply-booster-4`

**POST** `/api/user/apply-booster-5`

**POST** `/api/user/apply-booster-6`

**POST** `/api/user/apply-booster-7`

## Path parameters
None

## Query String
None

## Auth Headers / Tokens
```
Content-Type: application/json
x-game-token: <jwt_token>
```

## Enum Values

### Device ID
| Value | Description |
|-------|-------------|
| 1     | Web         |
| 2     | Android     |
| 3     | iOS         |
| 4     | iPad        |


## Request Payload

```json
{
    "event_group": {
        "phase_id": 1,
        "gameset_id": 9,
        "gameday_id": 3
    },
    "device_id": 1,
    "team_no": 1,
    "booster_id": 1,
    "player_id": 1006
}
```

## Response Json
```json
{
    "data": null,
    "meta": {
        "retval": 1,
        "message": "SUCCESS",
        "timestamp": "2025-06-11T07:06:36.000Z"
    }
}
```

---

