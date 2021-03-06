//
//  MIBlockManager.m
//  MatchIt
//
//  Created by Bill on 12-12-30.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "MIBlockManager.h"
#import "MIPositionConvert.h"
#import "MIConfig.h"
#import "CCLayerTouch.h"
#import "MIBlockManagerDelegate.h"
#import "MIMatching.h"
#import "MIRoute.h"
#import "MIMap.h"
#import "MIMatchingResult.h"

#import "CCParticleSystemQuad+DisplayFrame.h"

@implementation MIBlockManager

@synthesize blocks;
@synthesize selectedBlocks;

@synthesize map;

@synthesize delegate;

NSMutableArray *selectedSprites;

BOOL isPoping;

#pragma mark - init

-(id)init{
    if(self=[super init]){
        
        isPoping=NO;
        
        blocks=[[NSMutableArray alloc]init];
        selectedBlocks=[[NSMutableArray alloc]init];
        selectedSprites=[[NSMutableArray alloc]init];
        
        self.isTouchEnabled=YES;
        
        map=[[MIMap alloc]init];
        
        self.anchorPoint=ccp(0,0);
        self.position=ccp(0,0);
        
        [[CCSpriteFrameCache sharedSpriteFrameCache]addSpriteFramesWithFile:@"BasicImage.plist"];
        [[CCSpriteFrameCache sharedSpriteFrameCache]addSpriteFramesWithFile:@"stars.plist"];
        
        CCSprite *background=[CCSprite spriteWithSpriteFrameName:@"Background.png"];
        [background setPosition:ccp(0,0)];
        [background setAnchorPoint:ccp(0,0)];
        [self addChild:background];
        
        for(int i=0;i<BLOCKS_COUNT;i++){
            MIBlock *aBlock=[MIBlock blockWithBlockPosition:[MIPositionConvert indexToPositonWithIndex:i]];
            
            aBlock.delegate=self;
            
            [blocks addObject:aBlock];
            
            [self addChild:aBlock.blockSprite z:0];
            
            [self addChild:aBlock.blockRouteSprite z:1];
        }
        
        [self preloadParticleEffect];
        
        [self startGame];
    }
    return self;
}

-(void)startGame{
    [map newMap];
    
    for(int i=0;i<[blocks count];i++){
        MIBlock *aBlock=[blocks objectAtIndex:i];
        
        MIPosition *blockPosition=[MIPositionConvert indexToPositonWithIndex:i];
        
        [aBlock setBlockSpriteFrameWithFileName:[map imageNameAtX:blockPosition.x Y:blockPosition.y]];
        //[aBlock setBlockSpriteFrameWithFileName:[NSString stringWithFormat:@"Block_%i.png",blockPosition.y]];
        
        aBlock.blockSprite.anchorPoint=ccp(0,0);
        aBlock.blockSprite.position=ccp(BLOCKS_LEFT_X+BLOCKS_SIZE*blockPosition.x,BLOCKS_BOTTOM_Y+BLOCKS_SIZE*blockPosition.y);
        
        
        aBlock.blockRouteSprite.anchorPoint=ccp(0,0);
        aBlock.blockRouteSprite.position=ccp(BLOCKS_LEFT_X+BLOCKS_SIZE*blockPosition.x,BLOCKS_BOTTOM_Y+BLOCKS_SIZE*blockPosition.y);
        
    }

}

+(id)blockManager{
    return [[[self alloc]init]autorelease];
}

#pragma mark - Blocks Management

-(MIBlock*)blockAtIndex:(int)index{
    return (MIBlock*)[blocks objectAtIndex:index];
}

-(MIBlock*)blockAtX:(int)x Y:(int)y{
    return [self blockAtIndex:[MIPositionConvert positionToIndexWithX:x y:y]];
}

-(MIBlock*)blockAtPosition:(MIPosition*)position{
    return [self blockAtIndex:[MIPositionConvert positionToIndexWithX:position.x y:position.y]];
}

-(void)removeBlockAtIndex:(int)index{
    MIPosition *position=[MIPositionConvert indexToPositonWithIndex:index];
    [map setBlockAtX:position.x Y:position.y block:0];
    [[self blockAtIndex:index] setBlockSpriteFrameWithFileName:[map imageNameWithImgId:0]];
}

#pragma mark - Memory Management

-(void)dealloc{
    [super dealloc];
    [blocks release];
    [selectedBlocks release];
    [selectedSprites release];
}

#pragma mark - CCLayerDelegate

-(void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch=[touches anyObject];
    CGPoint touchPosition=[[CCDirector sharedDirector]convertToGL:[touch locationInView:[touch view]]];
    MIPosition *blockPosition=[MIPositionConvert screenToPositionWithX:touchPosition.x Y:touchPosition.y];
    
    if([MIPositionConvert blockISInAreaWithX:blockPosition.x Y:blockPosition.y]){
        MIBlock *block=[self blockAtX:blockPosition.x Y:blockPosition.y];
        [block blockBeingSelected];
    }else{
        if(delegate){
            [delegate traceWithString:@"Outside!"];
        }
    }
}

#pragma mark - MIBlockDelegate

-(void)blockBeingSelectedWithIndex:(int)blockIndex{
    if(!isPoping){
        MIBlock *block=[self blockAtIndex:blockIndex];
        MIPosition *blockPosition=block.blockPosition;
        //先判断这个方块是不是空的
        if([map blockAtX:blockPosition.x Y:blockPosition.y]!=0){
            //被选中的加入到数组,被取消选中的从数组中移除
            if(block.selected==NO){
                if(selectedBlocks.count==0){
                    [selectedBlocks addObject:[NSNumber numberWithInt:blockIndex]];
                    
                    CCSprite *sprite=[CCSprite spriteWithSpriteFrameName:@"Selected.png"];
                    sprite.anchorPoint=ccp(0,0);
                    sprite.position=ccp(BLOCKS_LEFT_X+BLOCKS_SIZE*blockPosition.x,BLOCKS_BOTTOM_Y+BLOCKS_SIZE*blockPosition.y);
                    [sprite setScale:BLOCKS_SIZE/BLOCKS_IMAGE_SIZE];
                    [self addChild:sprite z:2];
                    [selectedSprites addObject:sprite];
                    
                    block.selected=YES;
                }else if([selectedBlocks count]==1){
                    MIBlock *blockA=[self blockAtIndex:[[selectedBlocks objectAtIndex:0]intValue]];
                    MIPosition *blockPositionA=blockA.blockPosition;
                    MIPosition *blockB=blockPosition;
                    [self blockBeingSelectedWithIndex:[MIPositionConvert positionToIndexWithX:blockPositionA.x y:blockPositionA.y]];
                    
                    if([map blockAtX:blockPositionA.x Y:blockPositionA.y]==[map blockAtX:blockB.x Y:blockB.y]){
                        MIMatchingResult *matchResult=[MIMatching isMatchingWithA:blockPositionA B:blockB Map:map];
                        if(matchResult.matched){
                            MIRoute *route=matchResult.route;
                            [route parseVerteses];
                            [MIRoute drawRouteWithRoute:route manager:self];
                            
                            [self popBlockWithIndexA:[MIPositionConvert positionToIndexWithX:blockPositionA.x y:blockPositionA.y] IndexB:blockIndex];
                        }else{
                            NSLog(@"Not Matched");
                        }
                    }
                }
            }else{
                for(int i=0;i<[selectedBlocks count];i++){
                    NSNumber *selectedIndex=[selectedBlocks objectAtIndex:i];
                    if([selectedIndex intValue]==blockIndex){
                        [selectedBlocks removeObjectAtIndex:i];
                        [[selectedSprites objectAtIndex:i]removeFromParentAndCleanup:YES];
                        [selectedSprites removeObjectAtIndex:i];
                        block.selected=NO;
                    }
                }
            }
            if(delegate){
                [delegate traceWithString:[NSString stringWithFormat:@"X:%i,Y:%i,Selected:%d,All:%iSelected",blockPosition.x,blockPosition.y,block.selected,[selectedBlocks count]]];
            }
        }
    }
}

-(void)preloadParticleEffect{
    for(int i=0;i<POP_PARTICLE_IMAGES_COUNT;i++){
        [CCParticleSystemQuad particleWithFile:@"POPBlock.plist" DisplayFrameName:[NSString stringWithFormat:@"star_%i.png",i]];
        //[CCParticleSystemQuad particleWithFile:@"POPBlock.plist" DisplayFrameName:@"star_1.png"];
    }
    
    //[CCParticleSystemQuad particleWithFile:@"POPBlock.plist" DisplayFrameName:@"Block_1.png"];
}

-(void)popBlockWithIndexA:(int)indexA IndexB:(int)indexB{
    isPoping=YES;
    
    CCDelayTime *delay=[CCDelayTime actionWithDuration:0.5];
    CCCallFunc *clearRoute=[CCCallFunc actionWithTarget:self selector:@selector(clearRoute)];
    CCCallBlock *popBlockA=[CCCallBlock actionWithBlock:^(void){[self showPopParticleWithBlockIndex:indexA];}];
    CCCallBlock *popBlockB=[CCCallBlock actionWithBlock:^(void){[self showPopParticleWithBlockIndex:indexB];}];
    CCCallFunc *popEnded=[CCCallFunc actionWithTarget:self selector:@selector(popEnded)];
    
    [self runAction:[CCSequence actions:delay,clearRoute,popBlockA,popBlockB,popEnded,nil]];
    
}

-(void)clearRoute{
    for(MIBlock *block in blocks){
        [block setBlockRouteSpriteFrameWithFileName:@"Block_None.png"];
    }
}

-(void)showPopParticleWithBlockIndex:(int)index{
    //显示POP粒子效果的同时也移除方块
    MIPosition *blockPosition=[MIPositionConvert indexToPositonWithIndex:index];
    
    [self removeBlockAtIndex:index];
    
    CCParticleSystemQuad *system;
    //system=[CCParticleSystemQuad particleWithFile:@"POPBlock.plist" CustomTextureFile:[NSString stringWithFormat:@"star_%i.png",arc4random()%POP_PARTICLE_IMAGES_COUNT]];
    
    system=[CCParticleSystemQuad particleWithFile:@"POPBlock.plist" DisplayFrameName:[NSString stringWithFormat:@"star_%i.png",arc4random()%POP_PARTICLE_IMAGES_COUNT]];
    system.position=ccp(BLOCKS_LEFT_X+BLOCKS_SIZE*blockPosition.x+BLOCKS_SIZE/2,BLOCKS_BOTTOM_Y+BLOCKS_SIZE*blockPosition.y+BLOCKS_SIZE/2);
    [system setStartSize:BLOCKS_SIZE*1.5];
    [system setStartSizeVar:BLOCKS_SIZE*0.5];
    [system setEndSize:BLOCKS_SIZE*0.2];
    [system setEndSizeVar:BLOCKS_SIZE*0.2];
    
    [self addChild:system z:100];
    
}

-(void)popEnded{
    isPoping=NO;
    if([map unPoppedBlocks]==0){
        UIAlertView *alert=[[UIAlertView alloc]initWithTitle:@"YouWin" message:@"Congratulate!\nYou win the game!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    [self startGame];
}

@end
