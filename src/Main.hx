import haxegon.Convert;
import haxegon.*;

enum GameState {
    Normal;
    Gameover;
    End;
}

enum PlayerState {
    Idle;
    Moving;
    Attacking;
    Puking;
    Dying;
    Dead;
}

enum GoblinState {
    Moving;
    Attacking;
    Dying;
    Dead;
}

typedef Player = {
x: Int,
facingRight: Bool,
state: PlayerState,
stateTimer: Int,
attackTime: Int,
pukeDelay: Int,
pukeTimer: Int,
health: Int,
}

typedef Goblin = {
x: Int,
y: Int,
state: GoblinState,
stateTimer: Int,
attackTime: Int,
wasHit: Bool,
bloodTile: Int,
}

typedef Particle = {
x: Float,
y: Float,
width: Float,
widthFinal: Float,
t: Float,
tMax: Float,
dx: Float,
dy: Float,
ddy: Float
}

class Main {
    var gameState = GameState.Normal;
    var gameStateTimer = 0;
    var player: Player;
    var goblins = new Array<Goblin>();
    var pukePuddles = new Array<Int>();
    var particles = new Array<Particle>();

    var playerWidth = 30;
    var playerHeight = 40;

    var goblinWidth = 20;
    var goblinHeight = 22;

    var swordLength = 40;

    var leftBorder = -Gfx.screenWidthMid;
    var rightBorder = 3 * Gfx.screenWidthMid;

    var pukeDuration = 200;

    function new() {
        Gfx.resizeScreen(377, 240);
        Gfx.linethickness = 4;

        Music.loadSong("music");

        Gfx.loadTiles("player", playerWidth, playerHeight);
        Gfx.defineAnimation("player walk right", "player", 0, 1, 10);
        Gfx.defineAnimation("player walk left", "player", 3, 4, 10);

        Gfx.loadTiles("player death", 40, 40);
        Gfx.defineAnimation("player dying", "player death", 0, 4, 5);

        Gfx.loadTiles("puke left", 40, 40);
        Gfx.defineAnimation("player puke start", "puke left", 0, 3, 5);
        Gfx.defineAnimation("player puking", "puke left", 3, 4, 5);
        Gfx.defineAnimation("player puke end", "puke left", 5, 7, 5);

        Gfx.loadTiles("puke right", 40, 40);
        Gfx.defineAnimation("player puke start right", "puke right", 0, 3, 5);
        Gfx.defineAnimation("player puking right", "puke right", 3, 4, 5);
        Gfx.defineAnimation("player puke end right", "puke right", 5, 7, 5);

        Gfx.loadTiles("goblin", goblinWidth, goblinHeight);
        Gfx.defineAnimation("goblin walk", "goblin", 0, 1, 10);
        Gfx.defineAnimation("goblin walk hit", "goblin", 3, 4, 10);
        Gfx.loadTiles("goblin death", 30, 30);
        Gfx.defineAnimation("goblin dying", "goblin death", 0, 4, 4);

        Gfx.loadTiles("blood", 30, 9);

        Gfx.loadImage("sky");
        Gfx.loadImage("heart");
        Gfx.loadImage("sign");
        Gfx.loadImage("sign2");
        Gfx.loadImage("puke puddle");

        player = {
            x: 0,
            facingRight: true,
            state: PlayerState.Idle,
            stateTimer: 0,
            attackTime: 60,
            pukeDelay: 20,
            pukeTimer: 15,
            health: 3
        };

        spawnGoblins();
    }

    function spawnGoblins() {
        for (i in 0...5) {
            var goblin = {
                x: 200 + i * Convert.toInt(Gfx.screenWidth / 2),
                y: Gfx.screenHeightMid - 18,
                state: GoblinState.Moving,
                stateTimer: 0,
                attackTime: 60,
                wasHit: false,
                bloodTile: Random.int(0, 4)
            }
            goblins.push(goblin);
        }
    }

    function reset() {
        Gfx.stopAnimation("player walk left");
        Gfx.stopAnimation("player walk right");
        Gfx.stopAnimation("player dying");
        Gfx.stopAnimation("player puke start");
        Gfx.stopAnimation("player puking");
        Gfx.stopAnimation("player puke end");
        Gfx.stopAnimation("player puke start right");
        Gfx.stopAnimation("player puking right");
        Gfx.stopAnimation("player puke end right");
        Gfx.stopAnimation("goblin walk");
        Gfx.stopAnimation("goblin walk hit");
        Gfx.stopAnimation("goblin dying");

        player.x = 0;
        player.facingRight = true;
        player.state = PlayerState.Idle;
        player.stateTimer = 0;
        player.pukeTimer = 0;
        player.health = 3;

        particles.splice(0, particles.length);
        pukePuddles.splice(0, pukePuddles.length);
        goblins.splice(0, goblins.length);
        spawnGoblins();
    }

    function screenx(x: Int): Int {
        return Gfx.screenWidthMid + x - player.x;
    }

    function playerInput() {
        if (!(Input.pressed(Key.RIGHT) && Input.pressed(Key.LEFT))) {
            if (Input.pressed(Key.RIGHT)) {
                player.x += 2;
                player.state = PlayerState.Moving;
                player.facingRight = true;
            } else if (Input.pressed(Key.LEFT)) {
                player.x -= 2;
                player.state = PlayerState.Moving;
                player.facingRight = false;
            }

            if (player.x < leftBorder - 5) {
                player.x = leftBorder - 5;
            } else if (player.x > rightBorder - 25) {
                player.x = rightBorder - 25;
            } else {
                for (goblin in goblins) {
                    if (goblin.state != GoblinState.Dead && (goblin.x - player.x) < 20) {
                        player.x = goblin.x - 20;
                        break;
                    }
                }
            }
        }

        if (Input.pressed(Key.Z)) {
            player.state = PlayerState.Attacking;
            player.stateTimer = 0;
            player.facingRight = true;
        }
    }

    function pukeCheck() {
        for (goblin in goblins) {
            if (goblin.state == GoblinState.Dead) {
                if (player.facingRight
                && screenx(goblin.x) > screenx(player.x)
                && screenx(goblin.x) < Gfx.screenWidth) {
                    player.pukeTimer--;
                    if (player.pukeTimer <= 0) {
                        player.state = PlayerState.Puking;
                        player.stateTimer = 0;
                        break;
                    }
                } else if (!player.facingRight
                && screenx(goblin.x) < screenx(player.x)
                && screenx(goblin.x) > 10) {
                    player.pukeTimer--;
                    if (player.pukeTimer <= 0) {
                        player.state = PlayerState.Puking;
                        player.stateTimer = 0;
                        break;
                    }
                }
            }
        }
        if (player.state != PlayerState.Puking && player.pukeTimer > player.pukeDelay) {
            player.pukeTimer--;
        }
    }

    function spawnBlood(x: Int, y: Int, amount: Int) {
        var generaldx = Random.float(-0.4, 0.4);
        for (i in 0...amount) {
            var particle = {
                x : Convert.toFloat(x),
                y : Convert.toFloat(y),
                width : Random.float(0.0, 0.5),
                widthFinal : Random.float(0.75, 1.25),
                t : 0.0,
                tMax : 30 + Random.float(0, 10),
                dx : generaldx + Random.float(-0.4, 0.4),
                dy : Random.float(-1.0, -0.5),
                ddy : 0.03
            }
            particles.push(particle);
        }
    }

    function update() {
        switch (player.state) {
            case PlayerState.Idle : {
                playerInput();
                pukeCheck();
            }
            case PlayerState.Moving: {
                player.state = PlayerState.Idle;
                playerInput();
                pukeCheck();
            }
            case PlayerState.Attacking: {
                player.stateTimer++;
                if (player.stateTimer > player.attackTime) {
                    player.state = PlayerState.Moving;
                    if (player.facingRight) {
                        for (goblin in goblins) {
                            if (goblin.state != GoblinState.Dead
                            && goblin.x > player.x && goblin.x < player.x + 40) {
                                if (goblin.wasHit) {
                                    goblin.state = GoblinState.Dying;
                                    goblin.stateTimer = 0;
                                    spawnBlood(goblin.x + 20 + Random.int(-5, 5), 40 + Random.int(-5, 5), 10);
                                } else {
                                    goblin.wasHit = true;
                                    spawnBlood(goblin.x + Random.int(-5, 5), 35 + Random.int(-3, 3), 10);
                                }
                            }
                        }
                    }
                }
            }
            case PlayerState.Puking: {
                player.stateTimer++;
                if (player.stateTimer > pukeDuration) {
                    player.state = PlayerState.Idle;
                    player.pukeTimer = player.pukeDelay * 2;
                    if (player.facingRight) {
                        Gfx.stopAnimation("player puke start right");
                        Gfx.stopAnimation("player puking right");
                        Gfx.stopAnimation("player puke end right");
                    } else {
                        Gfx.stopAnimation("player puke start");
                        Gfx.stopAnimation("player puking");
                        Gfx.stopAnimation("player puke end");
                    }
                }
            }
            case PlayerState.Dying: {
                player.stateTimer++;
                if (player.stateTimer > 25) {
                    player.stateTimer = 0;
                    player.state = PlayerState.Dead;
                    Gfx.stopAnimation("player dying");
                }
            }
            case PlayerState.Dead: {

            }
        }

        for (goblin in goblins) {
            switch (goblin.state) {
                case GoblinState.Moving: {
                    if (Math.abs(goblin.x - player.x) < playerWidth) {
                        goblin.stateTimer++;
                        if (goblin.stateTimer > 10) {
                            goblin.state = GoblinState.Attacking;
                            goblin.stateTimer = 0;
                        }
                    } else if (Math.abs(goblin.x - player.x) < Gfx.screenWidthMid - 10) {
                        goblin.x -= MathUtils.sign(goblin.x - player.x);
                    }
                }
                case GoblinState.Attacking: {
                    goblin.stateTimer++;
                    if (goblin.stateTimer > goblin.attackTime) {
                        goblin.state = GoblinState.Moving;
                        goblin.stateTimer = 0;
                        if (Math.abs(goblin.x - player.x) < playerWidth / 2 + swordLength) {
                            if (player.health > 1) {
                                player.health--;
                                spawnBlood(player.x + 20 + Random.int(-5, 5), 20 + Random.int(-5, 5), 10);
                            } else if (player.state != PlayerState.Dead && player.state != PlayerState.Dying) {
                                player.health = 0;
                                player.state = PlayerState.Dying;
                                player.stateTimer = 0;
                            } else {
                                spawnBlood(player.x + 15 + Random.int(-10, 0), 30 + Random.int(-5, 5), 10);
                            }
                        }
                    }
                }
                case GoblinState.Dying: {
                    goblin.stateTimer ++;
                    if (goblin.stateTimer > 4 * 5) {
                        goblin.state = GoblinState.Dead;
                        goblin.stateTimer = 0;
                        Gfx.stopAnimation("goblin dying");
                    }
                }
                case GoblinState.Dead: {

                }
            }
        }

        for (particle in particles) {
            if (particle.t > particle.tMax) {
                particles.remove(particle);
            } else {
                if (particle.t > particle.tMax - 15) {
                    particle.width += 1;
                    particle.width = Math.min(particle.width, particle.widthFinal);
                }

                particle.x += particle.dx;
                particle.y += particle.dy;
                particle.dy += particle.ddy;
                particle.t++;
            }
        }


        Gfx.clearScreen(Col.LIGHTBLUE);
        Gfx.fillBox(0, Gfx.screenHeightMid, Gfx.screenWidth, Gfx.screenHeightMid, Col.LIGHTGREEN);
        Gfx.drawImage(-200 - player.x % (rightBorder), 0, "sky");
        if (player.x < leftBorder + Gfx.screenWidth) {
            Gfx.fillBox(screenx(-Gfx.screenWidth + leftBorder), 0, Gfx.screenWidth, Gfx.screenHeight, Col.LIGHTGREEN);
            Gfx.drawImage(screenx(leftBorder), Gfx.screenHeightMid - 40, "sign");
        } else if (player.x > rightBorder - Gfx.screenWidth) {
            Gfx.fillBox(screenx(rightBorder), 0, Gfx.screenWidth, Gfx.screenHeight, Col.LIGHTGREEN);
            Gfx.drawImage(screenx(rightBorder - 50), Gfx.screenHeightMid - 40, "sign2");
        }

        for (puddle in pukePuddles) {
            if (screenx(puddle) > -10 && screenx(puddle) < Gfx.screenWidth) {
                Gfx.drawImage(screenx(puddle), Gfx.screenHeightMid, "puke puddle");
            }
        }

        Gfx.changeTileset("player");
        switch (player.state) {
            case PlayerState.Idle: {
                if (player.facingRight) {
                    Gfx.drawTile(screenx(player.x), Gfx.screenHeightMid - 35, 0);
                } else {
                    Gfx.drawTile(screenx(player.x), Gfx.screenHeightMid - 35, 3);
                }
            }
            case PlayerState.Moving: {
                if (player.facingRight) {
                    Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player walk right");
                } else {
                    Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player walk left");
                }
            }
            case PlayerState.Attacking: {
                Gfx.drawTile(screenx(player.x), Gfx.screenHeightMid - 35, 2);
                var angle = (1 - player.stateTimer / player.attackTime) * Math.PI / 2 - Math.PI / 6;
                var x1 = screenx(player.x + Convert.toInt(playerWidth / 2));
                var y1 = Gfx.screenHeightMid - 20;
                var x2 = x1 + Math.cos(angle) * swordLength;
                var y2 = y1 - Math.sin(angle) * swordLength;
                Gfx.drawLine(x1, y1, x2, y2, Col.GRAY);
            }
            case PlayerState.Puking: {
                if (player.stateTimer == 15) {
                    if (player.facingRight) {
                        pukePuddles.push(player.x + 30);
                    } else {
                        pukePuddles.push(player.x - 20);
                    }
                }
                if (player.facingRight) {
                    if (player.stateTimer < 15) {
                        Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player puke start right");
                    } else if (player.stateTimer < pukeDuration - 15) {
                        Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player puking right");
                    } else {
                        Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player puke end right");
                    }
                } else {
                    if (player.stateTimer < 15) {
                        Gfx.drawAnimation(screenx(player.x - 20), Gfx.screenHeightMid - 35, "player puke start");
                    } else if (player.stateTimer < pukeDuration - 15) {
                        Gfx.drawAnimation(screenx(player.x - 20), Gfx.screenHeightMid - 35, "player puking");
                    } else {
                        Gfx.drawAnimation(screenx(player.x - 20), Gfx.screenHeightMid - 35, "player puke end");
                    }
                }
            }
            case PlayerState.Dying: {
                if (player.facingRight) {
                    Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player dying");
                } else {
                    Gfx.drawAnimation(screenx(player.x), Gfx.screenHeightMid - 35, "player dying");
                }
            }
            case PlayerState.Dead: {
                Gfx.changeTileset("player death");
                if (player.facingRight) {
                    Gfx.drawTile(screenx(player.x), Gfx.screenHeightMid - 35, 4);
                } else {
                    Gfx.drawTile(screenx(player.x), Gfx.screenHeightMid - 35, 4);
                }
            }
        }

        for (goblin in goblins) {
            if (screenx(goblin.x) > -50 && screenx(goblin.x) < Gfx.screenWidth + 50) {
                Gfx.changeTileset("goblin");
                switch (goblin.state) {
                    case GoblinState.Moving: {
                        if (goblin.wasHit) {
                            Gfx.drawAnimation(screenx(goblin.x), goblin.y, "goblin walk hit");
                        } else {
                            Gfx.drawAnimation(screenx(goblin.x), goblin.y, "goblin walk");
                        }
                    }
                    case GoblinState.Attacking: {
                        if (goblin.wasHit) {
                            Gfx.drawTile(screenx(goblin.x), goblin.y, 5);
                        } else {
                            Gfx.drawTile(screenx(goblin.x), goblin.y, 2);
                        }
                        var angle = (1 - goblin.stateTimer / goblin.attackTime) * Math.PI / 2 - Math.PI / 6;
                        var x2 = screenx(goblin.x + Convert.toInt(goblinWidth / 2)) - Math.cos(angle) * swordLength;
                        var y2 = goblin.y + 15 - Math.sin(angle) * swordLength;
                        Gfx.drawLine(screenx(goblin.x + Convert.toInt(goblinWidth / 2)), goblin.y + 10, x2, y2, Col.GREEN);
                    }
                    case GoblinState.Dying: {
                        Gfx.drawAnimation(screenx(goblin.x), goblin.y - 10, "goblin dying");
                    }
                    case GoblinState.Dead: {
                        Gfx.changeTileset("blood");
                        Gfx.drawTile(screenx(goblin.x), goblin.y + 20, goblin.bloodTile);
                        Gfx.changeTileset("goblin death");
                        Gfx.drawTile(screenx(goblin.x), goblin.y - 10, 4);
                    }
                }
            }
        }

        for (particle in particles) {
            Gfx.fillCircle(screenx(Convert.toInt(particle.x)), Gfx.screenHeightMid - 40 + particle.y, particle.width, Col.RED);
        }

        for (i in 0...player.health) {
            Gfx.drawImage(10 + i * 20, 10, "heart");
        }

        switch (gameState) {
            case GameState.Normal: {
                if (player.health <= 0) {
                    gameState = GameState.Gameover;
                } else if (player.x > rightBorder - Gfx.screenWidth * 3 / 4) {
                    gameState = GameState.End;
                    Music.playSong("music");
                }
            }
            case GameState.Gameover: {
                gameStateTimer++;
                if (gameStateTimer > 40) {
                    Gfx.fillBox(0, 0, Gfx.screenWidth, Gfx.screenHeight, Col.BLACK, (gameStateTimer + 40) / 200.0);
                } else if (gameStateTimer > 160) {
                    Gfx.fillBox(0, 0, Gfx.screenWidth, Gfx.screenHeight, Col.BLACK);
                }
                if (gameStateTimer > 220) {
                    gameState = GameState.Normal;
                    gameStateTimer = 0;
                    reset();
                }
            }
            case GameState.End: {
                if (player.health <= 0) {
                    gameState = GameState.Gameover;
                }
            }
        }
    }
}