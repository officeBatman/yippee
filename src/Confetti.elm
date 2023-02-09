module Confetti exposing (Model, Msg(..), init, update, view, subscriptions)

{-| HEADS UP! You can view this example alongside the running code at


We're going to make confetti come out of the party popper emoji: 🎉
([emojipedia](https://emojipedia.org/party-popper/)) Specifically, we're going
to lift our style from [Mutant Standard][ms], a wonderful alternate emoji set,
which is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike
4.0 International License.

[ms]: https://mutant.tech/

-}

import Html exposing (Html)
import Html.Attributes exposing (style)
import Particle exposing (Particle)
import Particle.System as System exposing (System)
import Random exposing (Generator)
import Random.Extra
import Random.Float exposing (normal)
import Svg exposing (Svg)
import Svg.Attributes as SAttrs



-- Generators!


{-| So, let's break down what we've got: this emoji is a cone bursting stuff
towards the upper right (you can see it at `tada.png` in the repo.) We have:

  - little brightly-colored squares. Looks like they can spin!
  - longer, wavy, brightly-colored streamers (but we'll just use rectangles here)

Let's model those as a custom type!

-}
type Confetti
    = Square
        { color : Color
        , rotations : Float

        -- we add a rotation offset to our rotations when rendering. It looks
        -- pretty odd if all the particles start or end in the same place, so
        -- this is part of our random generation.
        , rotationOffset : Float
        }
    | Streamer
        { color : Color
        , length : Int
        }


type Color
    = Red
    | Pink
    | Yellow
    | Green
    | Blue


{-| Generate a confetti square, using the color ratios seen in Mutant Standard.
-}
genSquare : Generator Confetti
genSquare =
    Random.map3
        (\color rotations rotationOffset ->
            Square
                { color = color
                , rotations = rotations
                , rotationOffset = rotationOffset
                }
        )
        (Random.weighted
            ( 1 / 5, Red )
            [ ( 1 / 5, Pink )
            , ( 1 / 5, Yellow )
            , ( 2 / 5, Green )
            ]
        )
        (normal 1 1)
        (Random.float 0 1)


{-| Generate a streamer, again using those color ratios
-}
genStreamer : Generator Confetti
genStreamer =
    Random.map2
        (\color length ->
            Streamer
                { color = color
                , length = round (abs length)
                }
        )
        (Random.uniform Pink [ Yellow, Blue ])
        (normal 25 10 |> Random.map (max 10))


{-| Generate confetti according to the ratios in Mutant Standard's tada emoji.
-}
genConfetti : Generator Confetti
genConfetti =
    Random.Extra.frequency
        ( 5 / 8, genSquare )
        [ ( 3 / 8, genStreamer ) ]


{-| We're going to emit particles at the mouse location, so we pass those
parameters in here and use them without modification.
-}
particleAt : Float -> Float -> Generator (Particle Confetti)
particleAt x y =
    Particle.init genConfetti
        |> Particle.withLifetime (normal 1.5 0.25)
        |> Particle.withLocation (Random.constant { x = x, y = y })
        |> Particle.withDirection (normal (degrees 0) (degrees 15))
        |> Particle.withSpeed (normal 750 150)
        |> Particle.withGravity 980
        |> Particle.withDrag
            (\confetti ->
                { density = 0.001226
                , coefficient =
                    case confetti of
                        Square _ ->
                            1.15

                        Streamer _ ->
                            0.85
                , area =
                    case confetti of
                        Square _ ->
                            1

                        Streamer { length } ->
                            toFloat length / 10
                }
            )


type alias Model =
    { system : System Confetti
    }


type Msg
    = TriggerBurst Float Float
    | ParticleMsg (System.Msg Confetti)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TriggerBurst x y ->
            ( { model | system = System.burst (Random.list 100 (particleAt x y)) model.system }
            , Cmd.none
            )

        ParticleMsg particleMsg ->
            ( { model | system = System.update particleMsg model.system }
            , Cmd.none
            )



-- views


view : Model -> Html msg
view model =
    Html.main_
        []
        [ System.view viewConfetti
            [ style "width" "100%"
            , style "height" "100%"
            , style "z-index" "1"
            , style "position" "fixed"
            , style "top" "0"
            , style "right" "0"
            , style "pointer-events" "none"
            ]
            model.system
        {-
        , Html.img
            [ Attrs.src "tada.png"
            , Attrs.width 64
            , Attrs.height 64
            , Attrs.alt "\"tada\" emoji from Mutant Standard"
            , style "position" "absolute"
            , style "left" (String.fromFloat (mouseX - 20) ++ "px")
            , style "top" (String.fromFloat (mouseY - 30) ++ "px")
            , style "user-select" "none"
            , style "cursor" "none"
            , style "z-index" "0"
            ]
            []
        -}
        ]


viewConfetti : Particle Confetti -> Svg msg
viewConfetti particle =
    let
        lifetime =
            Particle.lifetimePercent particle

        -- turns out that opacity is pretty expensive for browsers to calculate,
        -- and will slow down our framerate if we change it too much. So while
        -- we *could* do this with, like, a bezier curve or something, we
        -- actually want to just keep it as stable as possible until we actually
        -- need to fade out at the end.
        opacity =
            if lifetime < 0.1 then
                lifetime * 10

            else
                1
    in
    case Particle.data particle of
        Square { color, rotationOffset, rotations } ->
            Svg.rect
                [ SAttrs.width "10px"
                , SAttrs.height "10px"
                , SAttrs.x "-5px"
                , SAttrs.y "-5px"
                , SAttrs.rx "2px"
                , SAttrs.ry "2px"
                , SAttrs.fill (fill color)
                , SAttrs.stroke "black"
                , SAttrs.strokeWidth "4px"
                , SAttrs.opacity <| String.fromFloat opacity
                , SAttrs.transform <|
                    "rotate("
                        ++ String.fromFloat ((rotations * lifetime + rotationOffset) * 360)
                        ++ ")"
                ]
                []

        Streamer { color, length } ->
            Svg.rect
                [ SAttrs.height "10px"
                , SAttrs.width <| String.fromInt length ++ "px"
                , SAttrs.y "-5px"
                , SAttrs.rx "2px"
                , SAttrs.ry "2px"
                , SAttrs.fill (fill color)
                , SAttrs.stroke "black"
                , SAttrs.strokeWidth "4px"
                , SAttrs.opacity <| String.fromFloat opacity
                , SAttrs.transform <|
                    "rotate("
                        ++ String.fromFloat (Particle.directionDegrees particle)
                        ++ ")"
                ]
                []


fill : Color -> String
fill color =
    case color of
        Red ->
            "#D72D35"

        Pink ->
            "#F2298A"

        Yellow ->
            "#F2C618"

        Green ->
            "#2ACC42"

        Blue ->
            "#37CBE8"



init : Model
init =
    { system = System.init (Random.initialSeed 0)
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    System.sub [] ParticleMsg model.system
